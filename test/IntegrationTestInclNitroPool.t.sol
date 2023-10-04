// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

// token
import { XNeutroToken } from "../src/tokens/XNeutroToken.sol";
import { NeutroToken } from "../src/v1/NeutroToken.sol";
import { IXNeutroToken } from "../src/interfaces/tokens/IXNeutroToken.sol";
import { INeutroToken } from "../src/interfaces/tokens/INeutroToken.sol";
import { MockToken } from "./MockToken.sol";
import { IXNeutroTokenUsage } from "../src/interfaces/IXNeutroTokenUsage.sol";

// Farm
import { NFTPool } from "../src/nft-pool-factory/NFTPool.sol";
import { NFTPoolFactory } from "../src/nft-pool-factory/NFTPoolFactory.sol";
import { INeutroMaster } from "../src/interfaces/INeutroMaster.sol";
import { INFTPool } from "../src/interfaces//INFTPool.sol";
import { NeutroMaster } from "../src/nft-pool-factory/NeutroMaster.sol";

// Plugin
import { YieldBooster } from "../src/plugins/YieldBooster.sol";
import { Dividends } from "../src/plugins/Dividends.sol";

// Nitro
import { NitroPoolFactory } from "../src/nitro-pool/NitroPoolFactory.sol";
import { NitroPool } from "../src/nitro-pool/NitroPool.sol";

// misc
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IntergrationTestInclNitroPools is StdCheats, Test, ERC721Holder {
    NeutroToken internal neutro;
    INeutroToken internal _iNeutroToken;
    XNeutroToken internal xneutro;
    MockToken internal lpToken1;
    MockToken internal lpToken2;
    MockToken internal _rewardsToken1Nitro1;
    MockToken internal _rewardsToken2Nitro1;

    NFTPoolFactory internal nftPoolFactory;
    NFTPool internal nftPool1;
    NFTPool internal nftPool2;
    NeutroMaster internal master;
    NitroPoolFactory internal nitroFactory;
    NitroPool internal nitroPool1;
    NitroPool internal nitroPool2;

    Dividends internal dividends;
    YieldBooster internal yieldBooster;

    address alice = address(0x01);
    address butler = address(0x001);

    // !!!!!
    uint256 emissionStartTime_;
    uint256 emissionRate_ = 0.01 ether;
    uint256 treasuryAllocation_ = 50;
    uint256 farmingAllocation_ = 50;
    uint256 dividendStartTime;

    address public constant NEUTRO_OWNER =  0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7;
    address public constant TREASURY = address(0x02);

    uint256 lp1AmountAlice = 2 ether;
    uint256 addLp1AmountAlice = 8 ether;
    uint256 lp1LockPeriodAlice = 30 days;

    uint256 lp1AmountButler = 5 ether;
    uint256 addLp1AmountButler = 5 ether;
    uint256 lp1LockPeriodButler = 90 days;


    address nitroEmergencyRecoveryAddress = address(0x02);
    address nitroFeeAddress = address(0x03);

    uint256 _startTimeNitro1;
    uint256 _endTimeNitro1;
    uint256 _harvestStartTimeNitro1 = 0;
    uint256 _depositEndTimeNitro1 = 0;
    uint256 _lockDurationReqNitro1 = 0;
    uint256 _lockEndReqNitro1 = 0;
    uint256 _depositAmountReqNitro1 = 0;
    bool _whitelistNitro1 = false;
    string _descriptionNitro1 = "this is description";

    NitroPool.Settings _settingsNitro1;

    function setUp() public virtual {
        vm.createSelectFork({ urlOrAlias: "eos_evm_mainnet", blockNumber: 14_531_686 }); // fork test 

        emissionStartTime_ = block.timestamp + 7 days;
        neutro = NeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
        _iNeutroToken = INeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
        xneutro = new XNeutroToken(address(neutro));

        vm.startPrank(NEUTRO_OWNER);
        neutro.transfer(address(this), 100 ether);
        vm.stopPrank();

        master = new NeutroMaster(_iNeutroToken, emissionStartTime_, emissionRate_, treasuryAllocation_, farmingAllocation_, TREASURY);
        _grantRoleMinterToMaster();

        nftPoolFactory = new NFTPoolFactory(address(master), address(neutro), address(xneutro));

        dividendStartTime = block.timestamp + 7 days;
        dividends = new Dividends(address(xneutro), dividendStartTime);
        dividends.updateCycleDividendsPercent(address(xneutro), 10000); // 100%
        xneutro.updateDividendsAddress(address(dividends));
        xneutro.updateTransferWhitelist(address(dividends), true);

        yieldBooster = new YieldBooster(address(xneutro));
        master.setYieldBooster(address(yieldBooster));
        
        nitroFactory = new NitroPoolFactory(address(neutro), address(xneutro), nitroEmergencyRecoveryAddress, nitroFeeAddress);

        _startTimeNitro1 = block.timestamp + 1 days;
        _endTimeNitro1 = block.timestamp + 30 days;

        _settingsNitro1 = NitroPool.Settings (
            _startTimeNitro1,
            _endTimeNitro1,
            _harvestStartTimeNitro1,
            _depositEndTimeNitro1,
            _lockDurationReqNitro1,
            _lockEndReqNitro1,
            _depositAmountReqNitro1,
            _whitelistNitro1,
            _descriptionNitro1
        );
        _populateMockTokenAndPool();

        master.add(nftPool1, 50, true);
        // master.add(nftPool2, 100, true);

        _approveRewardsTokenToNitroPools(address(this), address(nitroPool1));
        _approveRewardsTokenToNitroPools(address(this), address(nitroPool2));
        
        uint256 rewardsAmountToken1 = 50 ether;
        uint256 rewardsAmountToken2 = 100 ether;
        
        nitroPool1.addRewards(rewardsAmountToken1, rewardsAmountToken2);
        nitroPool2.addRewards(rewardsAmountToken1, rewardsAmountToken2);
    }

   function testFarmSpNftAndDepositInNitroPoolWithYieldBooster() external {
        _approveLpTokenToSpNft(alice, address(nftPool1));
        _approveLpTokenToSpNft(butler, address(nftPool1));

        _createNftPool1Position(alice, lp1AmountAlice, lp1LockPeriodAlice);
        _createNftPool1Position(butler, lp1AmountButler, lp1LockPeriodButler);

        vm.expectRevert("not published");
        _depositSpNft1ToNitroPool(alice, address(nitroPool1), 1);

        nitroPool1.publish();
        _depositSpNft1ToNitroPool(alice, address(nitroPool1), 1);

        _harvestNftPool(alice, address(nftPool1));
        _harvestNitroPool(alice, address(nitroPool1));
        // no farm rewards and nitro rewards because both haven't started
        assert(_balanceXNeutroShouldStillBeZero(alice));
        assert(_balanceRewardTokenShouldStillBeZero(alice));

        // farm rewards still zero, but nitro rewards already emit the rewards (nitro already start)
        vm.warp(_startTimeNitro1 + 1);
        _harvestNftPool(alice, address(nftPool1));
        _harvestNitroPool(alice, address(nitroPool1));
        assert(_balanceXNeutroShouldStillBeZero(alice));
        assert(!_balanceRewardTokenShouldStillBeZero(alice));
        uint256 balanceNeutroFirstHarvestNFTPoolAlice = neutro.balanceOf(alice);
        uint256 balanceXNeutroFirstHarvestNFTPoolAlice = xneutro.balanceOf(alice);
        uint256 balanceFirstHarvestNitroAliceRewards1 = _rewardsToken1Nitro1.balanceOf(alice);  
        uint256 balanceFirstHarvestNitroAliceRewards2 = _rewardsToken2Nitro1.balanceOf(alice);

        // both farm and nitro already emit the rewards
        vm.warp(emissionStartTime_ + 1);
        _harvestNftPool(alice, address(nftPool1));
        _harvestNitroPool(alice, address(nitroPool1));
        _harvestNftPool(butler, address(nftPool1));
        _harvestNitroPool(butler, address(nitroPool1));

        // check emission (BUG balance in this test :( idk why) 
        console2.log(neutro.balanceOf(TREASURY));
        // console2.log(neutro.balanceOf(address(nftPool1)));
        console2.log(neutro.balanceOf(alice) + xneutro.balanceOf(alice));
        // console2.log(xneutro.balanceOf(alice));
        console2.log(neutro.balanceOf(butler) + xneutro.balanceOf(butler));
        // console2.log(xneutro.balanceOf(butler));
        // console2.log(neutro.balanceOf(alice) + xneutro.balanceOf(alice) + neutro.balanceOf(butler) + xneutro.balanceOf(butler) + neutro.balanceOf(TREASURY) + neutro.balanceOf(address(nftPool1)));

        assert(!_balanceXNeutroShouldStillBeZero(alice));
        assert(!_balanceRewardTokenShouldStillBeZero(alice));
        uint256 balanceNeutroSecondHarvestNFTPoolAlice = neutro.balanceOf(alice);
        uint256 balanceXNeutroSecondHarvestNFTPoolAlice = xneutro.balanceOf(alice);
        uint256 balanceSecondHarvestNitroAliceRewards1 = _rewardsToken1Nitro1.balanceOf(alice);  
        uint256 balanceSecondHarvestNitroAliceRewards2 = _rewardsToken2Nitro1.balanceOf(alice);
        assertGt(balanceNeutroSecondHarvestNFTPoolAlice, balanceNeutroFirstHarvestNFTPoolAlice);
        assertGt(balanceXNeutroSecondHarvestNFTPoolAlice, balanceXNeutroFirstHarvestNFTPoolAlice);
        assertGt(balanceSecondHarvestNitroAliceRewards1, balanceFirstHarvestNitroAliceRewards1);
        assertGt(balanceSecondHarvestNitroAliceRewards2, balanceFirstHarvestNitroAliceRewards2);

        // go to the end time nitro
        vm.warp(_endTimeNitro1);
        _harvestNftPool(alice, address(nftPool1));
        _harvestNitroPool(alice, address(nitroPool1));
        uint256 balanceNeutroThirdHarvestNFTPoolAlice = neutro.balanceOf(alice);
        uint256 balanceXNeutroThirdHarvestNFTPoolAlice = xneutro.balanceOf(alice);
        uint256 balanceThirdHarvestNitroAliceRewards1 = _rewardsToken1Nitro1.balanceOf(alice);  
        uint256 balanceThirdHarvestNitroAliceRewards2 = _rewardsToken2Nitro1.balanceOf(alice);
        assertGt(balanceNeutroThirdHarvestNFTPoolAlice, balanceNeutroSecondHarvestNFTPoolAlice);
        assertGt(balanceXNeutroThirdHarvestNFTPoolAlice, balanceXNeutroSecondHarvestNFTPoolAlice);
        assertGt(balanceThirdHarvestNitroAliceRewards1, balanceSecondHarvestNitroAliceRewards1);
        assertGt(balanceThirdHarvestNitroAliceRewards2, balanceSecondHarvestNitroAliceRewards2);

        // nitro rewards ended
        vm.warp(block.timestamp + 1 days);
        _harvestNftPool(alice, address(nftPool1));
        _harvestNitroPool(alice, address(nitroPool1));
        uint256 balanceFourthHarvestNitroAliceRewards1 = _rewardsToken1Nitro1.balanceOf(alice);  
        uint256 balanceFourthHarvestNitroAliceRewards2 = _rewardsToken2Nitro1.balanceOf(alice);
        assertEq(balanceFourthHarvestNitroAliceRewards1, balanceThirdHarvestNitroAliceRewards1);
        assertEq(balanceFourthHarvestNitroAliceRewards2, balanceThirdHarvestNitroAliceRewards2);

        // check the farm rewards per day
        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewardsBeforeBoostNFTPoolAlice = nftPool1.pendingRewards(1);
        _harvestNftPool(alice, address(nftPool1));

        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewards2BeforeBoostNFTPoolAlice = nftPool1.pendingRewards(1);
        _harvestNftPool(alice, address(nftPool1));
        // proof that we got static reward amount
        assertEq(pendingRewardsBeforeBoostNFTPoolAlice, pendingRewards2BeforeBoostNFTPoolAlice);

        // allocate to yield booster, harvest with boost
        uint256 tokenId = 1;
        vm.startPrank(alice);
        xneutro.approveUsage(IXNeutroTokenUsage(yieldBooster), 1 ether);
        xneutro.allocate(address(yieldBooster), 1 ether, abi.encode(address(nftPool1), tokenId));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewards3BeforeBoostNFTPoolAlice = nftPool1.pendingRewards(1);
        _harvestNftPool(alice, address(nftPool1));
        
        // pending rewards 3 > 2 becaue the boost
        assertGt(pendingRewards3BeforeBoostNFTPoolAlice, pendingRewards2BeforeBoostNFTPoolAlice);

        // proof that owner spNFT still nitroPool
        assertEq(nftPool1.ownerOf(1), address(nitroPool1));
   }

    function testDividends() external {
        vm.startPrank(NEUTRO_OWNER);
        neutro.transfer(alice, 10 ether);
        vm.stopPrank();
        _convertNeutroToXNeutro(alice, 10 ether);
        _allocateToDividendsPlugin(alice, 10 ether);
        _addRewardsAndHarvestDividends();
       
    }

    
    function _addRewardsAndHarvestDividends() internal {
        _convertNeutroToXNeutro(address(this), 80 ether);
        uint256 amountDividendToShare = 1 ether;
        uint256 amountDividendToShareCycle2 = 2 ether;
        uint256 addRewardsTokenAmountCycle2 = 10 ether;

        xneutro.approve(address(dividends), type(uint256).max);
        _rewardsToken1Nitro1.approve(address(dividends), type(uint256).max);

        dividends.addDividendsToPending(address(xneutro), amountDividendToShare);
        // dividends.massUpdateDividendsInfo();
        dividends.enableDistributedToken(address(xneutro));

        // jump to startTime_ + 1 days
        vm.warp(dividendStartTime + 1 days);
        uint256 balanceAliceBeforeFirstHarvest = xneutro.balanceOf(alice);

        vm.startPrank(alice);
        dividends.harvestAllDividends();
        vm.stopPrank();

        uint256 balanceAliceAfterFirstHarvest = xneutro.balanceOf(alice);
        assertGt(balanceAliceAfterFirstHarvest, balanceAliceBeforeFirstHarvest);

        vm.warp(dividendStartTime + 6 days);
        vm.startPrank(alice);
        dividends.harvestAllDividends();
        vm.stopPrank();

        uint256 balanceAliceAfterSecondHarvest = xneutro.balanceOf(alice);
        assertGt(balanceAliceAfterSecondHarvest, balanceAliceAfterFirstHarvest);
        
        // add dividens for next cycle (WE NEED TO DISTRIBUTE NEXT CYCLE AMOUNT BEFORE THE CURRENT CYCLE ENDS)
        vm.warp(dividendStartTime + 7 days - 1);
        dividends.addDividendsToPending(address(xneutro), amountDividendToShareCycle2);
        dividends.addDividendsToPending(address(_rewardsToken1Nitro1), addRewardsTokenAmountCycle2);
        dividends.enableDistributedToken(address(_rewardsToken1Nitro1));
        dividends.updateCycleDividendsPercent(address(_rewardsToken1Nitro1), 10000); // 100%

        vm.warp(dividendStartTime + 7 days);
        vm.startPrank(alice);
        dividends.harvestAllDividends();
        vm.stopPrank();

        uint256 balanceAliceAfterThirdHarvest = xneutro.balanceOf(alice);
        assertGt(balanceAliceAfterThirdHarvest, balanceAliceAfterSecondHarvest);
        assertEq(balanceAliceAfterThirdHarvest, amountDividendToShare); // equal because this cycle we only distribute "amountDividendToShare" amount

        vm.warp(dividendStartTime + 14 days);
        dividends.harvestAllDividends();
        vm.startPrank(alice);
        dividends.harvestAllDividends();
        vm.stopPrank();

        uint256 balanceAliceAfterFirstHarvestOnCycle2 = xneutro.balanceOf(alice);
        uint256 balanceAddTokenAliceAfterThirdHarvest = _rewardsToken1Nitro1.balanceOf(alice);
        assertGt(balanceAliceAfterFirstHarvestOnCycle2, balanceAliceAfterThirdHarvest);
        assertEq(balanceAliceAfterFirstHarvestOnCycle2, balanceAliceAfterThirdHarvest + amountDividendToShareCycle2); // equal because in this cycle 2 we only distribute "amountDividendToShare" amount
        assertEq(balanceAddTokenAliceAfterThirdHarvest, addRewardsTokenAmountCycle2); // equal because the rewads is fully distributed
        
        // run out of dividends amount to distribute, so this action wont change anything
        vm.warp(dividendStartTime + 14 days + 1 days);
        vm.startPrank(alice);
        dividends.harvestAllDividends();
        vm.stopPrank();
        uint256 lastBalanceAlice = xneutro.balanceOf(alice);
        uint256 lastAddTokenBalanceAlice = _rewardsToken1Nitro1.balanceOf(alice);
        assertEq(lastBalanceAlice, balanceAliceAfterFirstHarvestOnCycle2); // equal to prev cycle
        assertEq(lastAddTokenBalanceAlice, balanceAddTokenAliceAfterThirdHarvest); // equal to prev cycle
    }

    function _populateMockTokenAndPool() internal {
        _createToken();
        _createNftPool();
        _createNitroPool();
     }

    function _createToken() internal {
        lpToken1 = new MockToken("NeutroLP", "LP", address(this), 100 ether, 18);
        lpToken2 = new MockToken("NeutroLP", "LP", address(this), 100 ether, 18);
        _rewardsToken1Nitro1 = new MockToken("REWARD TOKEN 1", "RT1", address(this), 100 ether, 18);
        _rewardsToken2Nitro1 = new MockToken("REWARD TOKEN 2", "RT2", address(this), 100 ether, 18);

        lpToken1.transfer(alice, 50 ether);  
        lpToken1.transfer(butler, 50 ether);
      
    }

    function _createNftPool() internal {
        address nftPool1Address = nftPoolFactory.createPool(address(lpToken1));
        address nftPool2Address = nftPoolFactory.createPool(address(lpToken2));
        nftPool1 = NFTPool(nftPool1Address);
        nftPool2 = NFTPool(nftPool2Address);
    }

    function _createNitroPool() internal {
        address _nitroPool1 = nitroFactory.createNitroPool(address(nftPool1), address(_rewardsToken1Nitro1), address(_rewardsToken2Nitro1), _settingsNitro1);
        nitroPool1 = NitroPool(_nitroPool1);
        address _nitroPool2 = nitroFactory.createNitroPool(address(nftPool2), address(_rewardsToken1Nitro1), address(_rewardsToken2Nitro1), _settingsNitro1);
        nitroPool2 = NitroPool(_nitroPool2);
    }

    function _approveLpTokenToSpNft(address _who, address _nftPool) internal {
        vm.startPrank(_who);
        lpToken1.approve(_nftPool, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        lpToken2.approve(_nftPool, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.stopPrank();
    }

    function _approveRewardsTokenToNitroPools(address _who, address _nitroPool) internal {
        vm.startPrank(_who);
        _rewardsToken1Nitro1.approve(_nitroPool, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        _rewardsToken2Nitro1.approve(_nitroPool, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.stopPrank();
    }
 
    function _createNftPool1Position(address _who, uint256 _lpAmount, uint256 _lpLockPeriod) internal {
        vm.startPrank(_who);
        nftPool1.createPosition(_lpAmount, _lpLockPeriod);
        vm.stopPrank();
    }
       
   function _depositSpNft1ToNitroPool(address _who, address _nitroPool, uint256 _tokenId) internal {
        vm.startPrank(_who);
        nftPool1.safeTransferFrom(_who, _nitroPool, _tokenId);
        vm.stopPrank();
   }

    function _balanceXNeutroShouldStillBeZero(address _who) internal view returns (bool) {
        uint256 balance = xneutro.balanceOf(_who);
        if (balance > 0) {
            return false;
        } else {
            return true;
        }
    }

    function _balanceRewardTokenShouldStillBeZero(address _who) internal view returns (bool) {
        uint256 balance1 = _rewardsToken1Nitro1.balanceOf(_who);
        uint256 balance2 = _rewardsToken1Nitro1.balanceOf(_who);

        if (balance1 >  0 && balance2 > 0) {
            return false;
        } else {
            return true;
        }
    }

    function _harvestNftPool(address _who, address _nftPool) internal {
        vm.startPrank(_who);
        NFTPool(_nftPool).harvestPositionTo(1, _who);
        vm.stopPrank();
    }

    function _harvestNitroPool(address _who, address _nitroPool) internal {
        vm.startPrank(_who);
        NitroPool(_nitroPool).harvest();
        vm.stopPrank();
    }

    function _convertNeutroToXNeutro(address _who, uint256 _amount) internal {
        vm.startPrank(_who);
        neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        xneutro.convert(_amount);
        vm.stopPrank();
    }

    function _allocateToDividendsPlugin(address _who, uint256 _amount) internal {
        vm.startPrank(_who);
        xneutro.approveUsage(
          IXNeutroTokenUsage(dividends),
          0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        xneutro.allocate(address(dividends), _amount, "0x");
        vm.stopPrank();
    }

    function _grantRoleMinterToMaster() internal {
        vm.startPrank(NEUTRO_OWNER);
        neutro.grantRole(neutro.MINTER_ROLE(), address(master));
        vm.stopPrank();
    }
}
