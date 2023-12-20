// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { NeutroMaster } from "../src/nft-pool-factory/NeutroMaster.sol";
import { INeutroToken } from "../src/interfaces/tokens/INeutroToken.sol";
import { NeutroToken } from "../src/v1/NeutroToken.sol";
import { NeutroChef } from "../src/v1/NeutroChef.sol";
import { IBoringERC20 } from "../src/v1/interfaces/IBoringERC20.sol";
import { IMultipleRewards } from "../src/v1/interfaces/IMultipleRewards.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract NeutroV2Test is StdCheats, Test {
    NeutroMaster internal _master;
    INeutroToken internal _iNeutroToken;
    NeutroChef internal _chef; // old
    NeutroToken internal _neutroToken; 

    uint256 emissionStartTime_;
    uint256 emissionRate_ = 0.01 ether;
    uint256 treasuryAllocation_ = 20;
    uint256 farmingAllocation_ = 80;

    address public constant NEUTRO_OWNER = 0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7;
    address public constant TREASURY = address(0x01);
    uint256 public constant FALSE_TRANSFER_NEUTRO = 10 ether;
    uint256 public FORKED_NEUTRO_SUPPLY;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {      
        vm.createSelectFork({ urlOrAlias: "eos_evm_mainnet", blockNumber: 14_531_686 }); // fork test 

        _iNeutroToken = INeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
        _neutroToken = NeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
        _chef = NeutroChef(0xAA58d0658E7A8b0409C8C916AcAf85F8C7A706c2);
        FORKED_NEUTRO_SUPPLY = _neutroToken.totalSupply();
        
        emissionStartTime_ = block.timestamp + 7 days;
        _master = new NeutroMaster(_iNeutroToken, emissionStartTime_, emissionRate_, treasuryAllocation_, farmingAllocation_, TREASURY);
    }

    
    function test_DeactiveAllFarmInOldChef() external {
        
        address farmer = 0x62c620960E8E388C35BB6D64F365d1194519269f;
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingBeforeDeactive
        ) = _chef.pendingTokens(0, farmer);

        // assertGt to prove the chef still running
        vm.warp(block.timestamp + 5 days);
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingBeforeDeactive2
        ) = _chef.pendingTokens(0, farmer);
        assertGt(amountsPendingBeforeDeactive2[0], amountsPendingBeforeDeactive[0]);

 
        // deactive the chef
        _deactiveChef();
               

        vm.warp(block.timestamp + 10 days);
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingAfterDeactive1
        ) = _chef.pendingTokens(0, farmer);

        // assertEq to prove the chef already properly deactived (no rewards emitted)
        vm.warp(block.timestamp + 20 days);
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingAfterDeactive2
        ) = _chef.pendingTokens(0, farmer);
        assertEq(amountsPendingAfterDeactive2[0], amountsPendingAfterDeactive1[0]);


        // farmer success harvest the rewards in deactive state
        vm.startPrank(farmer);
        _chef.deposit(0, 0);
        vm.stopPrank();

        // assertEq to prove the chef already properly harvested by farmer
        vm.warp(block.timestamp + 20 days);
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingAfterHarvest
        ) = _chef.pendingTokens(0, farmer);
        assertEq(amountsPendingAfterHarvest[0], 0);

        // sanity checks again to make sure the rewards still zero 
        vm.warp(block.timestamp + 30 days);
        (
            ,
            ,
            ,
            uint256[] memory amountsPendingAfterHarvest2
        ) = _chef.pendingTokens(0, farmer);
        assertEq(amountsPendingAfterHarvest2[0], 0);

        // oldChefFarmInfo();
    }

    function test_NewMasterEmissionData() external {
        uint256 emissionRate = _master.emissionRate();
        uint256 farmingAllocation = _master.farmingAllocation();
        uint256 treasuryAllocation = _master.treasuryAllocation();

        assertEq(emissionRate, emissionRate_);
        assertEq(farmingAllocation, farmingAllocation_); // hardcoded at 50%
        assertEq(treasuryAllocation, treasuryAllocation_); // the rest of 100% allocation

        uint256 newEmissionRate = 0.001 ether;
        uint256 newFarmingAllocation = 60;
        uint256 newTreasuryAllocation = 40;
        _master.updateEmissionRate(newEmissionRate);
        _master.updateAllocations(newTreasuryAllocation, newFarmingAllocation);

        uint256 updatedEmissionRate = _master.emissionRate();
        uint256 updatedFarmingAllocation = _master.farmingAllocation();
        uint256 updatedTreasuryAllocation = _master.treasuryAllocation();

        assertEq(newEmissionRate, updatedEmissionRate);
        assertEq(newFarmingAllocation, updatedFarmingAllocation);
        assertEq(newTreasuryAllocation, updatedTreasuryAllocation);
    }



    function test_NeutroMasterEmissionOutput() external {
        _grantRoleMinterToMaster();

        uint256 emissionRate = _master.emissionRate();

        uint256 balanceNeutroBeforeEmitAllocation = _neutroToken.balanceOf(address(_master));
        uint256 balanceTreasuryNeutroBeforeEmitAllocation = _neutroToken.balanceOf(TREASURY);
        assertEq(balanceNeutroBeforeEmitAllocation, 0);
        assertEq(balanceTreasuryNeutroBeforeEmitAllocation, 0);

        vm.warp(_master.lastEmissionTime() + 1 days);
        _master.emitAllocations();

        uint256 balanceNeutroAfterEmitAllocation = _neutroToken.balanceOf(address(_master));
        uint256 balanceTreasuryNeutroAfterEmitAllocation = _neutroToken.balanceOf(TREASURY);
        uint256 tokenAmountCreatedForFarming = emissionRate * 1 days * _master.farmingAllocation() / 100;
        uint256 tokenAmountCreatedForTreasury = emissionRate * 1 days * _master.treasuryAllocation() / 100;
        uint256 totalTokenAmountCreated = (emissionRate * 1 days);

        assertEq(balanceNeutroAfterEmitAllocation, tokenAmountCreatedForFarming);
        assertEq(balanceTreasuryNeutroAfterEmitAllocation, tokenAmountCreatedForTreasury);
        assertEq(_neutroToken.totalSupply(), totalTokenAmountCreated + FORKED_NEUTRO_SUPPLY);

        uint256 newEmissionRate = 0.001 ether;
        uint256 newFarmingAllocation = 80;
        uint256 newTreasuryAllocation = 20;
        _master.updateEmissionRate(newEmissionRate);
        _master.updateAllocations(newFarmingAllocation, newTreasuryAllocation);

        vm.warp(_master.lastEmissionTime() + 1 days);
        _master.emitAllocations();

        uint256 updatedTokenAmountCreatedForFarming = newEmissionRate * 1 days * _master.farmingAllocation() / 100;
        uint256 updatedTokenAmountCreatedForTreasury = newEmissionRate * 1 days * _master.treasuryAllocation() / 100;
        uint256 updatedTotalTokenAmountCreated = (newEmissionRate * 1 days);
        uint256 balanceNeutroAfterUpdateAllocation = _neutroToken.balanceOf(address(_master));
        uint256 balanceTreasuryNeutroAfterUpdateAllocation = _neutroToken.balanceOf(TREASURY);

        assertEq(balanceNeutroAfterUpdateAllocation, balanceNeutroAfterEmitAllocation + updatedTokenAmountCreatedForFarming);
        assertEq(balanceTreasuryNeutroAfterUpdateAllocation, balanceTreasuryNeutroAfterEmitAllocation + updatedTokenAmountCreatedForTreasury);
        assertEq(_neutroToken.totalSupply(), totalTokenAmountCreated + updatedTotalTokenAmountCreated + FORKED_NEUTRO_SUPPLY);
    }

    // for sanity checks
    function oldChefFarmInfo() internal view {
        for(uint i; i < _chef.poolLength(); i++) {
            (
                IBoringERC20 lpToken, 
                uint256 allocPoint, 
                uint256 lastRewardTimestamp, 
                uint256 accNeutroPerShare, 
                , 
                uint256 harvestInterval, 
                uint256 totalLp 
            )  = _chef.poolInfo(i);
            console2.log(address(lpToken));
            console2.log(allocPoint);
            console2.log(lastRewardTimestamp);
            console2.log(accNeutroPerShare);
            console2.log(harvestInterval);
            console2.log(totalLp);

            console2.log("====================");
            console2.log();
        }
    }


    function _deactiveChef() internal {
         vm.startPrank(NEUTRO_OWNER);
        _chef.updateEmissionRate(0);
        vm.stopPrank();
    }

    function _grantRoleMinterToMaster() internal {
        vm.startPrank(NEUTRO_OWNER);
        _neutroToken.grantRole(_neutroToken.MINTER_ROLE(), address(_master));
        vm.stopPrank();
    }


}
