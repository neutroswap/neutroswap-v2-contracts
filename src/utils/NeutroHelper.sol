// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IXNeutroToken.sol";
import "./interfaces/IDividends.sol";
import "./interfaces/IPlugin.sol";
import "./interfaces/INeutroFactory.sol";
import "./interfaces/INeutroRouter.sol";
import "./interfaces/INeutroPair.sol";
import "./interfaces/INeutroMaster.sol";
import "./interfaces/INFTPool.sol";
import "./interfaces/INitroPool.sol";
import "./interfaces/INitroPoolFactory.sol";
import "./FullMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NeutroHelper is Ownable {
  bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()

  address public immutable WEOS;
  address public immutable NEUTRO;
  IXNeutroToken public xNeutro;
  IDividends public dividends;

  address[] public stableTokens;
  address public amm_factory;
  address public router;

  address public nitroPoolFactory;
  address public master;

  struct DividendsRewards {
    address token;
    uint256 currentDistributionAmount;
    uint256 pendingDistributionAmount;
    uint256 currentDistributionAmountInUsd;
    uint256 pendingDistributionAmountInUsd;
  }

  struct PendingRewardsUserInDividends {
    address token;
    uint256 amount;
    uint256 amountInUsd;
  }

  constructor(
    address _weos,
    address _neutro,
    address _xNeutro,
    address _usdt,
    address _usdc
  ) {
    WEOS = _weos;
    stableTokens.push(_usdt);
    stableTokens.push(_usdc);
    NEUTRO = _neutro;
    xNeutro = IXNeutroToken(_xNeutro);
  }

  function setAMMAddress(
    address _amm_factory,
    address _router
  ) external onlyOwner {
    amm_factory = _amm_factory;
    router = _router;
  }

  function setNeutroCoreAddress(
    address _master,
    address _dividends,
    address _nitroPoolFactory
  ) external onlyOwner {
    master = _master;
    dividends = IDividends(_dividends);
    nitroPoolFactory = _nitroPoolFactory;
  }

  function dividendsDistributedTokensRewards() public view returns (DividendsRewards[] memory) {
    uint256 l = dividends.distributedTokensLength();
    DividendsRewards[] memory _allDividendsRewards = new DividendsRewards[](l);
    for (uint256 i = 0; i < l; i++) {
      address _token = dividends.distributedToken(i);
      (uint256 currentDistributionAmount, , uint256 pendingAmount, , , , , ) = dividends.dividendsInfo(_token);
      uint256 currentDistributionAmountInUsd = FullMath.mulDiv(currentDistributionAmount, _fetchTotalValueOfLiquidity(_token), 10**18);
      uint256 pendingDistributionAmountInUsd = FullMath.mulDiv(pendingAmount,  _fetchTotalValueOfLiquidity(_token), 10**18);
      _allDividendsRewards[i] = DividendsRewards(_token, currentDistributionAmount, pendingAmount, currentDistributionAmountInUsd, pendingDistributionAmountInUsd);
    }
    return _allDividendsRewards;
  }

  function userAllocationInDividendsPlugin(address _user)
    external
    view
    returns (
      uint256 userTotalAllocation,
      uint256 userManualAllocation,
      uint256 userRedeemAllocation
    )
  {
    userTotalAllocation = dividends.usersAllocation(_user);
    userManualAllocation = xNeutro.usageAllocations(_user, address(dividends));
    uint256 l = xNeutro.getUserRedeemsLength(_user);
    for (uint256 i = 0; i < l; i++) {
      (, , , , uint256 dividendsAllocation) = xNeutro.getUserRedeem(_user, i);
      userRedeemAllocation += dividendsAllocation;
    }
  }

  function userPendingRewardsInDividendsPlugin(address _user)
    external
    view
    returns (PendingRewardsUserInDividends[] memory)
  {
    uint256 l = dividends.distributedTokensLength();
    PendingRewardsUserInDividends[] memory _allPendingRewards = new PendingRewardsUserInDividends[](l);
    for (uint256 i = 0; i < l; i++) {
      address _token = dividends.distributedToken(i);
      uint256 _pendingRewards = dividends.pendingDividendsAmount(_token, _user);
      uint256 _pendingRewardsAmountInUsd = FullMath.mulDiv(_pendingRewards, _fetchTotalValueOfLiquidity(_token), 10**18);
      _allPendingRewards[i] = PendingRewardsUserInDividends(_token, _pendingRewards, _pendingRewardsAmountInUsd);
    }
    return _allPendingRewards;
  }

  function deallocationFeePlugin(address _plugin) external view returns (uint256) {
    return xNeutro.usagesDeallocationFee(_plugin);
  }

  function totalAllocationAtPlugin(address _plugin) external view returns (uint256) {
    return IPlugin(_plugin).totalAllocation();
  }

  // Farming APR, returns in decimals 18
  function nftPoolApr(address _nftPool) external view returns (uint256) {
    (, , , , uint256 poolEmissionRate) = INeutroMaster(master).getPoolInfo(_nftPool);
    uint256 neutroPrice = _getNEUTROPrice();
    (address lpToken, , , , , uint256 totalLpStaked, ,) =  INFTPool(_nftPool).getPoolInfo();
    uint256 totalStakedInDollar = FullMath.mulDiv(_fetchTotalValueOfLiquidity(lpToken), totalLpStaked , 10**18);
    uint256 apr = FullMath.mulDiv(poolEmissionRate * 365 days * neutroPrice, 1, totalStakedInDollar) * 100; 
    return apr;
  }

  // Nitro APR, returns in decimals 18
  function nitroPoolApr(address _nitroPool) public view returns (uint256, uint256) {
    uint256 TO_DECIMAL_18 = 10**12;

    (address rewardsToken1,,,) = INitroPool(_nitroPool).rewardsToken1();
    (address rewardsToken2,,,) = INitroPool(_nitroPool).rewardsToken2();

    uint256 emissionRateReward1 = INitroPool(_nitroPool).rewardsToken1PerSecond();
    uint256 emissionRateReward2 = INitroPool(_nitroPool).rewardsToken2PerSecond();

    // assumption token decimals is 6 or 18
    if (safeDecimals(rewardsToken1) != 18) {
        emissionRateReward1 = emissionRateReward1 * TO_DECIMAL_18;
    }
    if (safeDecimals(rewardsToken2) != 18) {
        emissionRateReward2 = emissionRateReward2 * TO_DECIMAL_18;
    }

    uint256 neutroPrice = _getNEUTROPrice();
    address _nftPool = INitroPool(_nitroPool).nftPool();
    (address lpToken, , , , , , ,) =  INFTPool(_nftPool).getPoolInfo();
    uint256 _lpPrice = _fetchTotalValueOfLiquidity(lpToken);

    uint256 totalDepositedInNitroPool = INitroPool(_nitroPool).totalDepositAmount();

    if (totalDepositedInNitroPool > 0) {
      uint256 totalStakedInDollar = FullMath.mulDiv(_lpPrice, INitroPool(_nitroPool).totalDepositAmount(), (10**18));
      uint256 aprRewards1 = FullMath.mulDiv(emissionRateReward1 * 365 days * neutroPrice , 1, totalStakedInDollar) * 100;
      uint256 aprRewards2 = FullMath.mulDiv(emissionRateReward2 * 365 days * neutroPrice , 1, totalStakedInDollar) * 100;
      return (aprRewards1,aprRewards2);
    } else {
      return (0,0);
    }
  }

  // nitroPoolAprSpecificTOkenId -> if !staked return, 0
  function nitroPoolAprByNftPoolWithSpecificTokenId(address _nftPool, uint256 _tokenId) external view returns (uint256, uint256) {
      uint256 len = INitroPoolFactory(nitroPoolFactory).nftPoolPublishedNitroPoolsLength(_nftPool);
      address _ownerSpNFT = IERC721(_nftPool).ownerOf(_tokenId);

      for (uint256 i = 0; i < len; i++) {
        address _nitro = INitroPoolFactory(nitroPoolFactory).getNftPoolPublishedNitroPool(_nftPool, i);
        if (_ownerSpNFT == _nitro) {
            return nitroPoolApr(_nitro);
        }
      }

    return (0,0);
  }

  // Boost Multiplier, returns in % bps
  function getSpNftBoostMultiplier(address _nftPool, uint256 _tokenId) external view returns (uint256) {
    (uint256 amount,,,,,,uint256 boostPoint,) =  INFTPool(_nftPool).getStakingPosition(_tokenId);  
    uint256 boostMultiplier = INFTPool(_nftPool).getMultiplierByBoostPoints(amount, boostPoint);
    return boostMultiplier;
  }

  // Boost Multiplier, returns in % bps
  function getSpNftLockMultiplier(address _nftPool, uint256 _tokenId) external view returns (uint256) {
    (,,,uint256 lockDuration,,,,) =  INFTPool(_nftPool).getStakingPosition(_tokenId);  
    uint256 lockMultiplier = INFTPool(_nftPool).getMultiplierByLockDuration(lockDuration);
    return lockMultiplier;
  }
  
  // get reserveUSD, returns in decimals 18
  function getTotalValueOfLiquidity(address _lpToken) external view returns (uint256) {
    return _fetchTotalValueOfLiquidity(_lpToken);
  }

  function _fetchTotalValueOfLiquidity(address lpToken) internal view returns (uint256 price) {
    if (lpToken == address(xNeutro)) return _getNEUTROPrice();
    if (!_isValidLPToken(lpToken)) return _fetchPriceBasedOnRoutes(lpToken);
       
    address token0 = INeutroPair(lpToken).token0();
    address token1 = INeutroPair(lpToken).token1();

    (uint256 reserve0, uint256 reserve1, ) = INeutroPair(lpToken).getReserves();

    uint256 _decimals0 = safeDecimals(token0);
    uint256 _decimals1 = safeDecimals(token1);

    uint256 reserve0Usd = FullMath.mulDiv(_fetchPriceBasedOnRoutes(token0), reserve0, (10**_decimals0));    
    uint256 reserve1Usd = FullMath.mulDiv(_fetchPriceBasedOnRoutes(token1), reserve1, (10**_decimals1));    

    return reserve0Usd + reserve1Usd;
  }

  // we need to make it to decimals 18 from 6 (comes from common USD token) for normalize the number
  function getTokenPrice(address token) external view returns (uint256 price) {
    return _fetchPriceBasedOnRoutes(token);
  }

  function getNeutroPrice() external view returns (uint256 price) {
    return _getNEUTROPrice();
  }

  function _fetchPriceBasedOnRoutes(address token) internal view returns (uint256 price) {
    // first we check the usdt, next usdc
    address _pair = INeutroFactory(amm_factory).getPair(token, stableTokens[0]);
    if (_pair == address(0x00)) {
      _pair = INeutroFactory(amm_factory).getPair(token, stableTokens[1]);
        if (_pair == address(0x00)) {
          return _getUsdValueUsingWeosPair(token);
        } else {
          return _getUsdValueUsingUsdPair(token, stableTokens[1]);
        }
    } else {
      return _getUsdValueUsingUsdPair(token, stableTokens[0]);
    }
  }

  function _getUsdValueUsingWeosPair(address token) internal view returns (uint256 price) {
    uint256 TO_DECIMAL_18 = 10 ** 12;
    uint256 one_unit = 10**safeDecimals(token);

    if (token == WEOS) {
      return _getWEOSPrice();
    }

    address[] memory _path = new address[](3);
    _path[0] = token;
    _path[1] = WEOS;
    _path[2] = stableTokens[0];

    try INeutroRouter(router).getAmountsOut(one_unit, _path) returns (uint256[] memory result) {
      price = result[1] * TO_DECIMAL_18;
    } catch {
      price = 0;
    }
  }

  function _getUsdValueUsingUsdPair(address token, address stableToken) internal view returns (uint256 price) {
    uint256 TO_DECIMAL_18 = 10 ** 12;
    uint256 one_unit = 10**safeDecimals(token);

    if (token == stableTokens[0]) {
      return one_unit;
    }

    address[] memory _path = new address[](2);
    _path[0] = token;
    _path[1] = stableToken;

    try INeutroRouter(router).getAmountsOut(one_unit, _path) returns (uint256[] memory result) {
      price = result[1] * TO_DECIMAL_18;
    } catch {
      price = 0;
    }
  }

  function _getWEOSPrice() internal view returns (uint256 price) {
    uint256 TO_DECIMAL_18 = 10 ** 12;
    uint256 one_unit = 10**18;
    address[] memory _path = new address[](2);
    _path[0] = WEOS;
    _path[1] = stableTokens[0];
    uint256[] memory result = INeutroRouter(router).getAmountsOut(one_unit, _path);
    price = result[1] * TO_DECIMAL_18;
  }

  function _getNEUTROPrice() internal view returns (uint256 price) {
    uint256 TO_DECIMAL_18 = 10 ** 12;
    uint256 one_unit = 10**18;
    address[] memory _path = new address[](2);
    _path[0] = NEUTRO;
    _path[1] = stableTokens[0];
    uint256[] memory result = INeutroRouter(router).getAmountsOut(one_unit, _path);
    price = result[1] * TO_DECIMAL_18;
  }

  /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
  /// @param _token The address of the ERC-20 token contract.
  /// @return (uint8) Token decimals.
  function safeDecimals(address _token) private view returns (uint8) {
    (bool success, bytes memory data) = address(_token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
    return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
  }

  function _isValidLPToken(address lpToken) internal view returns (bool) {
      // We try to retrieve the token0 from the lpToken.
      // If this operation fails, it's likely not a valid LP token.
      try INeutroPair(lpToken).token0() returns (address) {
          return true;
      } catch {
          return false;
      }
  }

}
