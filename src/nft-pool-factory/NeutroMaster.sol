// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/INeutroMaster.sol";
import "../interfaces/INFTPool.sol";
import "../interfaces/IYieldBooster.sol";
import "../interfaces/tokens/INeutroToken.sol";

/*
 * This contract centralizes Neutro's yield incentives distribution.
 * Pools that should receive those incentives are defined here, along with their allocation.
 * All rewards are claimed and distributed by this contract.
 */
contract NeutroMaster is Ownable, INeutroMaster {
  using SafeERC20 for INeutroToken;
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  // Info of each NFT pool
  struct PoolInfo {
    uint256 allocPoint; // How many allocation points assigned to this NFT pool
    uint256 lastRewardTime; // Last time that distribution to this NFT pool occurs
    uint256 reserve; // Pending rewards to distribute to the NFT pool
  }

  INeutroToken private immutable _neutroToken; // Address of the NEUTRO token contract
  IYieldBooster private _yieldBooster; // Contract address handling yield boosts

  mapping(address => PoolInfo) private _poolInfo; // Pools' information
  EnumerableSet.AddressSet private _pools; // All existing pool addresses
  EnumerableSet.AddressSet private _activePools; // Only contains pool addresses w/ allocPoints > 0

  uint256 public constant MAX_EMISSION_RATE = 0.01 ether;
  uint256 public immutable emissionStartTime; // The time at which emission starts
  uint256 public emissionRate; // $NEUTRO created per sec
  uint256 public lastEmissionTime;

  uint256 public constant ALLOCATION_PRECISION = 100;
  uint256 public treasuryAllocation; // Treasury alloc point
  uint256 public farmingAllocation; // Farming alloc point
  address public treasury;
  uint256 public totalAllocPoint; // Total allocation points. Must be the sum of all allocation points in all pools
  bool public override emergencyUnlock; // Used by pools to release all their locks at once in case of emergency

  constructor(
    INeutroToken neutroToken_,
    uint256 emissionStartTime_,
    uint256 emissionRate_,
    uint256 treasuryAllocation_,
    uint256 farmingAllocation_,
    address treasury_
  ) {
    require(_currentBlockTimestamp() < emissionStartTime_ , "NeutroMaster: invalid emissionStartTime");
    require(emissionRate_ <= MAX_EMISSION_RATE, "NeutroMaster: emission rate can't exceed maximum");
    require(treasuryAllocation_ + farmingAllocation_ <= 100, "NeutroMaster: total allocation is too high");

    _neutroToken = neutroToken_;
    emissionStartTime = emissionStartTime_; 
    emissionRate = emissionRate_;
    treasuryAllocation = treasuryAllocation_; 
    farmingAllocation = farmingAllocation_;
    lastEmissionTime = emissionStartTime_;
    treasury = treasury_;
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event UpdateAllocations(uint256 farmingAllocation, uint256 treasuryAllocation);
  event UpdateEmissionRate(uint256 previousEmissionRate, uint256 newEmissionRate);
  event AllocationsDistributed(uint256 farmShare, uint256 treasuryShare);
  event ClaimRewards(address indexed poolAddress, uint256 amount);
  event PoolAdded(address indexed poolAddress, uint256 allocPoint);
  event PoolSet(address indexed poolAddress, uint256 allocPoint);
  event SetYieldBooster(address previousYieldBooster, address newYieldBooster);
  event SetTreasury(address previousTreasury, address newTreasury);
  event PoolUpdated(address indexed poolAddress, uint256 reserve, uint256 lastRewardTime);
  event SetEmergencyUnlock(bool emergencyUnlock);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Check if a pool exists
   */
  modifier validatePool(address poolAddress) {
    require(_pools.contains(poolAddress), "validatePool: pool does not exist");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /*
   * @dev Returns NeutroToken address
   */
  function neutroToken() external view override returns (address) {
    return address(_neutroToken);
  }

  /*
   * @dev Returns farm emission rate
   */
  function farmEmissionRate() public view returns (uint256) {
    return emissionRate.mul(farmingAllocation).div(ALLOCATION_PRECISION);
  }


  /**
   * @dev Returns current owner's address
   */
  function owner() public view virtual override(INeutroMaster, Ownable) returns (address) {
    return Ownable.owner();
  }

  /**
   * @dev Returns YieldBooster's address
   */
  function yieldBooster() external view override returns (address) {
    return address(_yieldBooster);
  }

  /**
   * @dev Returns the number of available pools
   */
  function poolsLength() external view returns (uint256) {
    return _pools.length();
  }

  /**
   * @dev Returns a pool from its "index"
   */
  function getPoolAddressByIndex(uint256 index) external view returns (address) {
    if (index >= _pools.length()) return address(0);
    return _pools.at(index);
  }

  /**
   * @dev Returns the number of active pools
   */
  function activePoolsLength() external view returns (uint256) {
    return _activePools.length();
  }

  /**
   * @dev Returns an active pool from its "index"
   */
  function getActivePoolAddressByIndex(uint256 index) external view returns (address) {
    if (index >= _activePools.length()) return address(0);
    return _activePools.at(index);
  }

  /**
   * @dev Returns data of a given pool
   */
  function getPoolInfo(address poolAddress_) external view override returns (
    address poolAddress, uint256 allocPoint, uint256 lastRewardTime, uint256 reserve, uint256 poolEmissionRate
  ) {
    PoolInfo memory pool = _poolInfo[poolAddress_];

    poolAddress = poolAddress_;
    allocPoint = pool.allocPoint;
    lastRewardTime = pool.lastRewardTime;
    reserve = pool.reserve;

    if (totalAllocPoint == 0) {
      poolEmissionRate = 0;
    } else {
      poolEmissionRate = farmEmissionRate().mul(allocPoint).div(totalAllocPoint);
    }
  }


  /*******************************************************/
  /****************** OWNABLE FUNCTIONS ******************/
  /*******************************************************/

  /**
   * @dev Updates $NEUTRO emission rate per second
   *
   * Must only be called by the owner
   */
  function updateEmissionRate(uint256 emissionRate_) external onlyOwner {
    require(emissionRate_ <= MAX_EMISSION_RATE, "updateEmissionRate: can't exceed maximum");

    // apply emissions before changes
    _emitAllocations();

    emit UpdateEmissionRate(emissionRate, emissionRate_);
    emissionRate = emissionRate_;
  }


  /**
   * @dev Updates emission allocations between farming incentives, and treasury
   *
   * Must only be called by the owner
   */
  function updateAllocations(uint256 treasuryAllocation_, uint256 farmingAllocation_) external onlyOwner {
    // apply emissions before changes
    _emitAllocations();

    // total sum of allocations can't be > 100%
    require(treasuryAllocation_ + farmingAllocation_ <= 100, "updateAllocations: total allocation is too high");

    // set new allocations
    treasuryAllocation = treasuryAllocation_;
    farmingAllocation = farmingAllocation_;

    emit UpdateAllocations(farmingAllocation_, treasuryAllocation);
  }

  /**
   * @dev Set YieldBooster contract's address
   *
   * Must only be called by the owner
   */
  function setYieldBooster(address yieldBooster_) external onlyOwner {
    require(yieldBooster_ != address(0), "setYieldBooster: cannot be set to zero address");
    emit SetYieldBooster(address(_yieldBooster), yieldBooster_);
    _yieldBooster = IYieldBooster(yieldBooster_);
  }

  /**
   * @dev Set Treasury address
   *
   * Must only be called by the owner
   */
  function setTreasury(address treasury_) external onlyOwner {
    require(treasury_ != address(0), "setTreasury: cannot be set to zero address");
    emit SetTreasury(treasury, treasury_);
    treasury = treasury_;
  }


  /**
   * @dev Set emergency unlock status for all pools
   *
   * Must only be called by the owner
   */
  function setEmergencyUnlock(bool emergencyUnlock_) external onlyOwner {
    emergencyUnlock = emergencyUnlock_;
    emit SetEmergencyUnlock(emergencyUnlock);
  }

  /**
   * @dev Adds a new pool
   * param withUpdate should be set to true every time it's possible
   *
   * Must only be called by the owner
   */
  function add(INFTPool nftPool, uint256 allocPoint, bool withUpdate) external onlyOwner {
    address poolAddress = address(nftPool);
    require(!_pools.contains(poolAddress), "add: pool already exists");
    uint256 currentBlockTimestamp = _currentBlockTimestamp();

    if (allocPoint > 0) {
      if (withUpdate) {
        // Update all pools if new pool allocPoint > 0
        _massUpdatePools();
      }
      _activePools.add(poolAddress);
    }

    // update lastRewardTime if emissionStartTime has already been passed
    uint256 lastRewardTime = currentBlockTimestamp > emissionStartTime ? currentBlockTimestamp : emissionStartTime;

    // update totalAllocPoint with the new pool's points
    totalAllocPoint = totalAllocPoint.add(allocPoint);

    // add new pool
    _poolInfo[poolAddress] = PoolInfo({
    allocPoint : allocPoint,
    lastRewardTime : lastRewardTime,
    reserve : 0
    });
    _pools.add(poolAddress);

    emit PoolAdded(poolAddress, allocPoint);
  }

  /**
   * @dev Updates configuration on existing pool
   * param withUpdate should be set to true every time it's possible
   *
   * Must only be called by the owner
   */
  function set(address poolAddress, uint256 allocPoint, bool withUpdate) external validatePool(poolAddress) onlyOwner {
    PoolInfo storage pool = _poolInfo[poolAddress];
    uint256 prevAllocPoint = pool.allocPoint;

    if (withUpdate) {
      _massUpdatePools();
    }
    _updatePool(poolAddress);

    // update (pool's and total) allocPoints
    pool.allocPoint = allocPoint;
    totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(allocPoint);

    // if request is activating the pool
    if (prevAllocPoint == 0 && allocPoint > 0) {
      _activePools.add(poolAddress);
    }
    // if request is deactivating the pool
    else if (prevAllocPoint > 0 && allocPoint == 0) {
      _activePools.remove(poolAddress);
    }

    emit PoolSet(poolAddress, allocPoint);
  }


  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  /**
   * @dev Emit $NEUTRO Emission
   */
  function emitAllocations() external {
    _emitAllocations();
  }


  /**
   * @dev Updates rewards states of the given pool to be up-to-date
   */
  function updatePool(address nftPool) external validatePool(nftPool) {
    _updatePool(nftPool);
  }

  /**
   * @dev Updates rewards states for all pools
   *
   * Be careful of gas spending
   */
  function massUpdatePools() external {
    _massUpdatePools();
  }

  /**
   * @dev Transfer to a pool its pending rewards in reserve, can only be called by the NFT pool contract itself
   */
  function claimRewards() external override returns (uint256 rewardsAmount) {
    // check if caller is a listed pool
    if (!_pools.contains(msg.sender)) {
      return 0;
    }

    _updatePool(msg.sender);

    // updates caller's reserve
    PoolInfo storage pool = _poolInfo[msg.sender];
    uint256 reserve = pool.reserve;
    if (reserve == 0) {
      return 0;
    }
    pool.reserve = 0;

    emit ClaimRewards(msg.sender, reserve);
    return _safeRewardsTransfer(msg.sender, reserve);
  }


  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Safe token transfer function, in case rounding error causes pool to not have enough tokens
   */
  function _safeRewardsTransfer(address to, uint256 amount) internal returns (uint256 effectiveAmount) {
    uint256 neutroBalance = _neutroToken.balanceOf(address(this));

    if (amount > neutroBalance) {
      amount = neutroBalance;
    }

    _neutroToken.safeTransfer(to, amount);
    return amount;
  }

  /**
   * @dev Updates rewards states of the given pool to be up-to-date
   *
   * Pool should be validated prior to calling this
   */
  function _updatePool(address poolAddress) internal {
    _emitAllocations();

    PoolInfo storage pool = _poolInfo[poolAddress];

    uint256 currentBlockTimestamp = _currentBlockTimestamp();

    uint256 lastRewardTime = pool.lastRewardTime; // gas saving
    uint256 allocPoint = pool.allocPoint; // gas saving

    if (currentBlockTimestamp <= lastRewardTime) {
      return;
    }

    // do not allocate rewards if pool is not active
    if (allocPoint > 0 && INFTPool(poolAddress).hasDeposits()) {
      // calculate how much rewards are expected to be received for this pool
      uint256 rewards = currentBlockTimestamp.sub(lastRewardTime) // nbSeconds
        .mul(farmEmissionRate()).mul(allocPoint).div(totalAllocPoint);

      // cap asked amount with available reserve
      uint farmReserve = _neutroToken.balanceOf(address(this));
      uint effectiveAmount = Math.min(farmReserve, rewards);

      if (effectiveAmount == 0) {
        return;
      }
      
      // updates pool data
      pool.reserve = pool.reserve.add(effectiveAmount);
    }

    pool.lastRewardTime = currentBlockTimestamp;

    emit PoolUpdated(poolAddress, pool.reserve, currentBlockTimestamp);
  }

  /**
   * @dev Updates rewards states for all pools
   *
   * Be careful of gas spending
   */
  function _massUpdatePools() internal {
    uint256 length = _activePools.length();
    for (uint256 index = 0; index < length; ++index) {
      _updatePool(_activePools.at(index));
    }
  }

  /**
   * @dev Mint $NEUTRO Emission
   *
   * Treasury share is directly minted to the treasury address
   * Farm incentives are minted into this contract and claimed later by NFT pool
   */
  function _emitAllocations() internal {
    uint256 currentBlockTimestamp = _currentBlockTimestamp();
    uint256 _lastEmissionTime = lastEmissionTime; // gas saving

    // if already up to date or not started
    if (currentBlockTimestamp <= _lastEmissionTime) {
      return;
    }

    uint256 neutroCirculatingSupply = _neutroToken.totalSupply();
    uint256 neutroMaxSupply = _neutroToken.getMaxTotalSupply();

    // if max supply is already reached or emissions deactivated
    if (neutroMaxSupply <= neutroCirculatingSupply || emissionRate == 0) {
      lastEmissionTime = currentBlockTimestamp;
      return;
    }

    // calculate how much NEUTRO emission are expected
    uint256 emissionAmount = currentBlockTimestamp.sub(_lastEmissionTime).mul(emissionRate);

    if (neutroMaxSupply <= neutroCirculatingSupply.add(emissionAmount)) {
      emissionAmount = neutroMaxSupply.sub(neutroCirculatingSupply);
    }
   
    // calculate farm and treasury shares from new emissions
    uint256 farmShare = emissionAmount.mul(farmingAllocation).div(ALLOCATION_PRECISION);
    // sub to avoid rounding errors
    uint256 treasuryShare = emissionAmount.sub(farmShare);

    lastEmissionTime = currentBlockTimestamp;

    _neutroToken.mint(address(this), farmShare);
    _neutroToken.mint(treasury, treasuryShare);

    emit AllocationsDistributed(farmShare, treasuryShare);
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }

}
