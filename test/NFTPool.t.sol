// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import { YieldBooster } from "../src/plugins/YieldBooster.sol";
import { NFTPool } from "../src/nft-pool-factory/NFTPool.sol";
import { NFTPoolFactory } from "../src/nft-pool-factory/NFTPoolFactory.sol";
import { XNeutroToken } from "../src/tokens/XNeutroToken.sol";
import { NeutroToken } from "../src/v1/NeutroToken.sol";
import { INeutroToken } from "../src/interfaces/tokens/INeutroToken.sol";
import { INeutroMaster } from "../src/interfaces/INeutroMaster.sol";
import { INFTPool } from "../src/interfaces//INFTPool.sol";
import { NeutroMaster } from "../src/nft-pool-factory/NeutroMaster.sol";
import { IXNeutroToken } from "../src/interfaces/tokens/IXNeutroToken.sol";
import { INeutroToken } from "../src/interfaces/tokens/INeutroToken.sol";
import { MockToken } from "./MockToken.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import { IYieldBooster } from "../src/interfaces/IYieldBooster.sol";
import { IXNeutroTokenUsage } from "../src/interfaces/IXNeutroTokenUsage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTPoolTest is StdCheats, Test, ERC721Holder {
    using SafeMath for uint256;

    NFTPoolFactory internal factory;
    NFTPool internal nftPool1;
    NFTPool internal nftPool2;
    NeutroMaster internal master;

    NeutroToken internal neutro;
    INeutroToken internal _iNeutroToken;
    XNeutroToken internal xneutro;

    MockToken internal lpToken1;
    MockToken internal lpToken2;

    YieldBooster internal yieldBooster;
    
    uint256 emissionStartTime_;
    uint256 emissionRate_ = 0.01 ether;
    uint256 treasuryAllocation_ = 50;
    uint256 farmingAllocation_ = 50;

    address alice = address(0x01);
    uint256 lpAmountAlice = 2 ether;
    uint256 addLpAmountAlice = 8 ether;
    uint256 lpLockPeriodAlice = 30 days;

    address butler = address(0x03);
    uint256 lpAmountButler = 2 ether;
    uint256 lpLockPeriodButler = 60 days;

    address public constant NEUTRO_OWNER = 0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7;
    address public constant TREASURY = address(0x02);
    
    function setUp() public virtual {
        vm.createSelectFork({ urlOrAlias: "eos_evm_mainnet", blockNumber: 14_531_686 }); // fork test 

        emissionStartTime_ = block.timestamp + 7 days;
        neutro = NeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
        _iNeutroToken = INeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);

        xneutro = new XNeutroToken(address(neutro));
        master = new NeutroMaster(_iNeutroToken, emissionStartTime_, emissionRate_, treasuryAllocation_, farmingAllocation_, TREASURY);
        factory = new NFTPoolFactory(address(master), address(neutro), address(xneutro));
        yieldBooster = new YieldBooster(address(xneutro));
        lpToken1 = new MockToken("NeutroLP", "LP", alice, 100 ether, 18);
        lpToken2 = new MockToken("NeutroLP", "LP", alice, 100 ether, 18);

        address nftPool1Address = factory.createPool(address(lpToken1));
        address nftPool2Address = factory.createPool(address(lpToken2));
        nftPool1 = NFTPool(nftPool1Address);
        nftPool2 = NFTPool(nftPool2Address);

        
        // neutro.updateAllocations(64); // 64 = farming allocation, the rest goes to treasury allocation
        // xneutro.updateDeallocationFee(address(yieldbooster), 200); // deallocation fee 2%
        master.setYieldBooster(address(yieldBooster));

        _populateLpTokenToAliceAndButler();
        
        _grantRoleMinterToMaster();
    }

    function testAddandSetPoolInMaster() public {
        uint256 totalPool = master.poolsLength();
        assertEq(totalPool, 0);
        uint256 masterActivePool = master.activePoolsLength();
        assertEq(masterActivePool, 0);

        (address poolAddress, uint256 allocPoint, , , uint256 poolEmissionRate ) = master.getPoolInfo(address(nftPool1));
        assertEq(poolAddress, address(nftPool1));
        assertEq(allocPoint, 0); // not added or active yet
        assertEq(poolEmissionRate, 0); // not added or active yet

        uint256 allocPointForNftPool1 = 20;
        master.add(INFTPool(address(nftPool1)), allocPointForNftPool1, true);

        uint256 totalPoolAfterAddNftPool1 = master.poolsLength();
        assertEq(totalPoolAfterAddNftPool1, 1);
        uint256 masterActivePoolAfterAddNftPool1 = master.activePoolsLength();
        assertEq(masterActivePoolAfterAddNftPool1, 1);

        (address poolAddressAfterAddNftPool1, uint256 allocPointAfterAddNftPool1, , , uint256 poolEmissionRateAfterAddNftPool1) = master.getPoolInfo(address(nftPool1));
        assertEq(poolAddressAfterAddNftPool1, address(nftPool1));
        assertEq(allocPointAfterAddNftPool1, allocPointForNftPool1); // not added or active yet
        assertEq(poolEmissionRateAfterAddNftPool1, master.farmEmissionRate() * allocPointForNftPool1 / master.totalAllocPoint());

        uint256 newAllocPointForNftPool1 = 50;
        master.set(address(nftPool1), newAllocPointForNftPool1, true);
        (, uint256 newAllocPointAfterSetNftPool1, , , uint256 newPoolEmissionRateAfterSetNftPool1) = master.getPoolInfo(address(nftPool1));
        assertEq(newAllocPointAfterSetNftPool1, newAllocPointForNftPool1); // not added or active yet
        assertEq(newPoolEmissionRateAfterSetNftPool1, master.farmEmissionRate() * newAllocPointForNftPool1 / master.totalAllocPoint());
    }

    function testCreateNftPoolPosition() public {
        vm.startPrank(alice);
        nftPool1.createPosition(lpAmountAlice, lpLockPeriodAlice);
        nftPool2.createPosition(lpAmountAlice, lpLockPeriodAlice);
        vm.stopPrank();

        (
            uint256 amount, , uint256 startLockTime, uint256 lockDuration, , , ,
        ) = nftPool1.getStakingPosition(1);

        assertEq(amount, lpAmountAlice);
        assertEq(startLockTime, block.timestamp);
        assertEq(lockDuration, lpLockPeriodAlice);
    }

    function testAddToPositonNftPool() public {
        _createNftPoolPositionForAlice();

        vm.startPrank(alice);
        nftPool1.addToPosition(1, addLpAmountAlice);
        vm.stopPrank();

        (
            uint256 amount, , uint256 startLockTime, , , , ,
        ) = nftPool1.getStakingPosition(1);

        assertEq(amount, lpAmountAlice + addLpAmountAlice);
        assertEq(startLockTime, block.timestamp); // renew the lock
    }

    function testAllocPointProperlyAssignedInMaster() public {
        _setAllocPointInMaster();

        // check if the alloc point is properly assigned
        (,uint256 allocPoint1,,, uint256 poolEmissionRate1) = master.getPoolInfo(address(nftPool1));
        (,uint256 allocPoint2,,, uint256 poolEmissionRate2) = master.getPoolInfo(address(nftPool2));

        uint256 farmEmissionRate = emissionRate_.mul(farmingAllocation_).div(master.ALLOCATION_PRECISION());
        uint256 _poolEmissionRate1 = farmEmissionRate.mul(allocPoint1).div(master.totalAllocPoint());
        uint256 _poolEmissionRate2 = farmEmissionRate.mul(allocPoint2).div(master.totalAllocPoint());
        uint256 treasuryEmissionRate = emissionRate_.mul(treasuryAllocation_).div(master.ALLOCATION_PRECISION());

        assertEq(poolEmissionRate1, _poolEmissionRate1);
        assertEq(poolEmissionRate2, _poolEmissionRate2);

        // make sure the total emissionRate in pool + treasury equal to assigned emissionRate
        assertEq(poolEmissionRate1 + poolEmissionRate2 + treasuryEmissionRate, emissionRate_);
    }

    function testCheckPendingRewardsAndEmissionOutput() public {
        uint256 initialBalanceNeutroAlice = neutro.balanceOf(alice);
        uint256 initialBalanceXNeutroAlice = xneutro.balanceOf(alice);
        uint256 initialBalanceNeutroButler = neutro.balanceOf(butler);
        uint256 initialBalanceXNeutroButler = xneutro.balanceOf(butler);
        // make sure its the fresh start
        assertEq(initialBalanceNeutroAlice + initialBalanceXNeutroAlice + initialBalanceNeutroButler + initialBalanceXNeutroButler, 0);

        _setAllocPointInMaster();
        _createNftPoolPositionForAlice();
        _createNftPoolPositionForButler();

        vm.warp(emissionStartTime_ + 1);

        // manual checks for the tokenId, Aliec => 1, Butler => 2
        vm.startPrank(alice);
        uint256 pendingRewardsAlice = nftPool1.pendingRewards(1);
        nftPool1.harvestPosition(1);
        nftPool2.harvestPosition(1);
        vm.stopPrank();

        vm.startPrank(butler);
        uint256 pendingRewardsButler = nftPool1.pendingRewards(2);
        nftPool1.harvestPosition(2);
        nftPool2.harvestPosition(2);
        vm.stopPrank();


        // 80% xNEUTRO 20% NEUTRO
        uint256 balanceNeutroAliceAfterHarvest = neutro.balanceOf(alice);
        uint256 balanceXNeutroAliceAfterHarvest = xneutro.balanceOf(alice);
        uint256 balanceNeutroButlerAfterHarvest = neutro.balanceOf(butler);
        uint256 balanceXNeutroButlerAfterHarvest = xneutro.balanceOf(butler);

        assertGt(balanceNeutroAliceAfterHarvest, initialBalanceNeutroAlice);
        assertGt(balanceXNeutroAliceAfterHarvest, initialBalanceXNeutroAlice);
        assertGt(balanceXNeutroAliceAfterHarvest, balanceNeutroAliceAfterHarvest);
        assertGt(balanceNeutroButlerAfterHarvest, initialBalanceNeutroButler);
        assertGt(balanceXNeutroButlerAfterHarvest, initialBalanceXNeutroButler);
        assertGt(balanceXNeutroButlerAfterHarvest, balanceNeutroButlerAfterHarvest);

        console2.log("Alice", balanceNeutroAliceAfterHarvest + balanceXNeutroAliceAfterHarvest);
        console2.log("Butler", balanceNeutroButlerAfterHarvest + balanceXNeutroButlerAfterHarvest);
        console2.log("Total", balanceNeutroButlerAfterHarvest + balanceXNeutroButlerAfterHarvest +  balanceNeutroAliceAfterHarvest + balanceXNeutroAliceAfterHarvest);

        // Butler got more rewards because the lockPeriod > Alice
        assertGt(balanceNeutroButlerAfterHarvest + balanceXNeutroButlerAfterHarvest, balanceNeutroAliceAfterHarvest + balanceXNeutroAliceAfterHarvest);

        // make sure the emission is correctly emitted with 2 NFT Pool and 2 users in each NFT Pool
        // +2 for small diff
        assertEq(
            neutro.balanceOf(TREASURY) +
            balanceNeutroAliceAfterHarvest + balanceXNeutroAliceAfterHarvest +
            balanceNeutroButlerAfterHarvest + balanceXNeutroButlerAfterHarvest 
            +  4, 
            emissionRate_
        );
    }

    function testLockBonus() public {
        _setAllocPointInMaster();
        _createNftPoolPositionForAlice();
        _createNftPoolPositionForButler();

        vm.warp(emissionStartTime_ + 1);
        uint256 pendingRewardsAliceNftPool1 = nftPool1.pendingRewards(1);
        uint256 pendingRewardsButlerNftPool1 = nftPool1.pendingRewards(2);
        uint256 pendingRewardsAliceNftPool2 = nftPool2.pendingRewards(1);
        uint256 pendingRewardsButlerNftPool2 = nftPool2.pendingRewards(2);

        // in % bps, we manual calculated it to make sure it works :)
        // first NFTPool
        uint256 multiplierAliceNftPool1 = (lpLockPeriodAlice * 10000 / 183 days);
        uint256 multiplierAmountAliceNftPool1 = lpAmountAlice * multiplierAliceNftPool1 / 10000;
        uint256 multiplierButlerNftPool1 = (lpLockPeriodButler  * 10000 / 183 days);
        uint256 multiplierAmountButlerNftPool1 = lpAmountButler * multiplierButlerNftPool1 / 10000;
        uint256 lpAmountWithMultiplierAliceNftPool1 = lpAmountAlice + multiplierAmountAliceNftPool1;
        uint256 lpAmountWithMultiplierButlerNftPool1 = lpAmountButler + multiplierAmountButlerNftPool1;
        uint256 totalLpAmountWithMultiplier = lpAmountWithMultiplierAliceNftPool1 + lpAmountWithMultiplierButlerNftPool1;
        // 0.0025 because farm emission is 0.01/2 = (0.005) and divided with 2 NFTPool, so each pool reward is 0.005/2 
        uint256 expectedRewardsAliceNftPool1 = lpAmountWithMultiplierAliceNftPool1 * 0.0025 ether / totalLpAmountWithMultiplier;
        uint256 expectedRewardsButlerNftPool1 = lpAmountWithMultiplierButlerNftPool1 * 0.0025 ether / totalLpAmountWithMultiplier;

        // small diff
        // assertEq(pendingRewardsAliceNftPool1, expectedRewardsAliceNftPool1);
        // assertEq(pendingRewardsButlerNftPool1, expectedRewardsButlerNftPool1);

        vm.startPrank(alice);
        uint256 pendingRewardsAlice = nftPool1.pendingRewards(1);
        nftPool1.harvestPosition(1);
        vm.stopPrank();

        vm.startPrank(butler);
        uint256 pendingRewardsButler = nftPool1.pendingRewards(2);
        nftPool1.harvestPosition(2);
        vm.stopPrank();

        uint256 balanceNeutroAliceAfterHarvest = neutro.balanceOf(alice);
        uint256 balanceXNeutroAliceAfterHarvest = xneutro.balanceOf(alice);
        uint256 balanceNeutroButlerAfterHarvest = neutro.balanceOf(butler);
        uint256 balanceXNeutroButlerAfterHarvest = xneutro.balanceOf(butler);

        // proof that this locking mechanism didn't mint fresh token again to cover up the bonus
        // it takes the portion of emission rewards
        // eq to emissionRate / 2 for farming rate, divided by 2 again remembering we run this test using 2 NFTPool with same allocPoint
        // small diff
        assertEq(
            balanceNeutroAliceAfterHarvest + balanceXNeutroAliceAfterHarvest +
            balanceNeutroButlerAfterHarvest + balanceXNeutroButlerAfterHarvest + 2, 
            // expectedRewardsAliceNftPool1 + expectedRewardsButlerNftPool1  
            emissionRate_ / 2 / 2
        );
        
    }

    function testRenewLocksPosition() public {
        _createNftPoolPositionForAlice();

        vm.warp(block.timestamp + 1 days);

        (
            , , uint256 startLockTimeBeforeRenew,
            uint256 lockDurationBeforeRenew, , ,
            ,
        ) = nftPool1.getStakingPosition(1);
        assertEq(lockDurationBeforeRenew, lpLockPeriodAlice);
        assertEq(1 days, block.timestamp - startLockTimeBeforeRenew); // eq to 1 days ahead because our warp

        vm.startPrank(alice);
        uint256 newLockPeriod = 60 days;
        nftPool1.lockPosition(1, newLockPeriod);
        vm.stopPrank();

        (
            , , uint256 startLockTimeAfterRenew,
            uint256 lockDurationAfterRenew, , ,
            ,
        ) = nftPool1.getStakingPosition(1);
        assertEq(startLockTimeAfterRenew, block.timestamp);
        assertEq(newLockPeriod, lockDurationAfterRenew);
    }

    function testSplitNftPoolPosition() public {
        _createNftPoolPositionForAlice();

        uint256 amountToSplit = 1 ether;
        vm.startPrank(alice);
        nftPool1.splitPosition(1, amountToSplit);
        vm.stopPrank();

        (
            uint256 amountTokenId1AfterSplit, , ,
            , , ,
            ,
        ) = nftPool1.getStakingPosition(1);
        assertEq(amountTokenId1AfterSplit, lpAmountAlice - amountToSplit);

        (
            uint256 amountTokenId2AfterSplit, , ,
            , , ,
            ,
        ) = nftPool1.getStakingPosition(2);
        assertEq(amountTokenId2AfterSplit, amountToSplit);
    }

    function testMergeNftPoolPosition() public {
        testSplitNftPoolPosition();

        vm.startPrank(alice);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        nftPool1.mergePositions(tokenIds, 30 days);
        (
            uint256 amountAfterMerge
            ,
            ,
            ,
            ,
            ,
            ,
            ,
        ) = nftPool1.getStakingPosition(1);
        assertEq(amountAfterMerge, lpAmountAlice);
        vm.stopPrank();
    }

    // yieldBooster
    function testBoostNftPool() public {
        _createNftPoolPositionForAlice();
        _convertNeutroToXNEUTROandApproveToYieldBooster();

        vm.startPrank(alice);
        uint256 allocatedXNEUTRO = 2 ether;
        uint256 tokenIdAlice = 1;
        bytes memory data = abi.encode(address(nftPool1), tokenIdAlice);
        xneutro.allocate(address(yieldBooster), allocatedXNEUTRO, data);
        vm.stopPrank();

        (
        ,
        ,
        ,
        ,
        ,
        ,
        uint256 boostPoint
        ,
        ) = nftPool1.getStakingPosition(tokenIdAlice);
        assertGt(boostPoint, 0); // boosted

    }

    function testUnBoostNftPool() public {
        testBoostNftPool();
        vm.startPrank(alice);
        uint256 dellocatedXNEUTRO = 2 ether;
        uint256 tokenIdAlice = 1;
        bytes memory data = abi.encode(address(nftPool1), tokenIdAlice);
        xneutro.deallocate(address(yieldBooster), dellocatedXNEUTRO, data);
        vm.stopPrank();

        (
        ,
        ,
        ,
        ,
        ,
        ,
        uint256 boostPoint
        ,
        ) = nftPool1.getStakingPosition(tokenIdAlice);
        assertEq(boostPoint, 0); // ubboosted
    }

    function _convertNeutroToXNEUTROandApproveToYieldBooster() public {
        _trfNeutroToAliceFromDeployer();

        vm.startPrank(alice);
        neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        xneutro.convert(10 ether);
        xneutro.approveUsage(IXNeutroTokenUsage(address(yieldBooster)), 10 ether);
        vm.stopPrank();
    }

    function _trfNeutroToAliceFromDeployer() internal {
        vm.startPrank(NEUTRO_OWNER);
        neutro.transfer(alice, 10 ether);
        vm.stopPrank();
    }

    function _populateLpTokenToAliceAndButler() public {
        vm.startPrank(alice);
        lpToken1.approve(address(nftPool1), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        lpToken2.approve(address(nftPool2), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        lpToken1.transfer(butler, 10 ether);
        lpToken2.transfer(butler, 10 ether);
        vm.stopPrank();

        vm.startPrank(butler);
        lpToken1.approve(address(nftPool1), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        lpToken2.approve(address(nftPool2), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        vm.stopPrank();
    }

    function _createNftPoolPositionForAlice() public {
        vm.startPrank(alice);
        nftPool1.createPosition(lpAmountAlice, lpLockPeriodAlice);
        nftPool2.createPosition(lpAmountAlice, lpLockPeriodAlice);
        vm.stopPrank();
    }

    function _createNftPoolPositionForButler() public {
        vm.startPrank(butler);
        nftPool1.createPosition(lpAmountButler, lpLockPeriodButler);
        nftPool2.createPosition(lpAmountButler, lpLockPeriodButler);
        vm.stopPrank();
    }

    function _setAllocPointInMaster() public {
        // Master add alloc point to pool
        master.add(nftPool1, 150, true);
        master.add(nftPool2, 150, true);
    }

    function _grantRoleMinterToMaster() internal {
        vm.startPrank(NEUTRO_OWNER);
        neutro.grantRole(neutro.MINTER_ROLE(), address(master));
        vm.stopPrank();
    }
}
