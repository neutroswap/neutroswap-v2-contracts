// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Dividends } from "../src/plugins/Dividends.sol";
import { XNeutroToken } from "../src/tokens/XNeutroToken.sol";
import { NeutroToken } from "../src/v1/NeutroToken.sol";
import { IXNeutroTokenUsage } from "../src/interfaces/IXNeutroTokenUsage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DividendsTest is StdCheats, Test {
  Dividends internal dividends;
  XNeutroToken internal xneutro;
  NeutroToken internal neutro;

  address alice = address(0x100);
  address butler = address(0x101);
  uint256 startTime_;

  address token1 = address(0x11);
  address token2;

  uint256 initialXNeutroBalanceAlice = 10 ether;
  uint256 initialXNeutroBalanceButler = 10 ether;

  uint256 allocateAmountToPluginAddressThis = 1 ether;
  uint256 allocateAmountToPluginAlice = 1 ether;
  uint256 allocateAmountToPluginButler = 1 ether;

  address public constant NEUTRO_OWNER = 0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7;

  function setUp() public virtual {
     vm.createSelectFork({ urlOrAlias: "eos_evm_mainnet", blockNumber: 14_531_686 }); // fork test

    startTime_ = block.timestamp + 1 days;

    neutro = NeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
    xneutro = new XNeutroToken(address(neutro));
    dividends = new Dividends(address(xneutro), startTime_);

    token2 = address(xneutro);

    vm.startPrank(NEUTRO_OWNER);
    neutro.transfer(alice, initialXNeutroBalanceAlice);
    neutro.transfer(butler, initialXNeutroBalanceAlice);
    neutro.transfer(address(this), 100 ether);
    vm.stopPrank();

    _approveAndConvertTokenToXNeutro(alice, initialXNeutroBalanceAlice);
    _approveAndConvertTokenToXNeutro(butler, initialXNeutroBalanceButler);
    _approveAndConvertTokenToXNeutro(address(this), 100 ether);
    _approveXNeutroToDividendPlugin(address(this));

    xneutro.updateTransferWhitelist(address(dividends), true);

    dividends.updateCycleDividendsPercent(address(xneutro), 10000); // 100%
  }

  function testCycleDurationSeconds() external {
    uint256 _cycleduration = dividends.cycleDurationSeconds();
    assertEq(_cycleduration, 7 days); // every 7 days
  }

  function testDividendsData() external {
    _allocateToDividensPlugin(alice, allocateAmountToPluginAlice);
    _allocateToDividensPlugin(address(this), allocateAmountToPluginAddressThis);
    _allocateToDividensPlugin(butler, allocateAmountToPluginButler);

    dividends.enableDistributedToken(address(xneutro));

    // add dividends to pending (to distribute in next cycle)
    uint256 amountDividendToShare = 1 ether;
    dividends.addDividendsToPending(address(xneutro), amountDividendToShare);
    // dividends.massUpdateDividendsInfo();

    // check is the token is ready to distribute
    assertEq(dividends.isDistributedToken(token2), true);

    uint256 distributedTokensLength = dividends.distributedTokensLength();
    assertEq(distributedTokensLength, 1);

    // for triggering the dividends data
    vm.warp(startTime_ + 1);
    dividends.harvestAllDividends();

    vm.warp(startTime_ + 1 days);
    uint256 balanceAliceBeforeFirstHarvest = xneutro.balanceOf(alice);
    uint256 pendingDividendsAliceInCycle1 = dividends.pendingDividendsAmount(address(xneutro), alice);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();
    uint256 balanceAliceAfterFirstHarvest = xneutro.balanceOf(alice);
    assertEq(balanceAliceBeforeFirstHarvest + pendingDividendsAliceInCycle1, balanceAliceAfterFirstHarvest);
    
    vm.warp(startTime_ + 7 days);
    uint256 pendingDividendsAliceInNextCycle1 = dividends.pendingDividendsAmount(address(xneutro), alice);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();
    uint256 balanceAliceAfterNextHarvest = xneutro.balanceOf(alice);
    // use Gt because there's a small unit diff
    assertGt(balanceAliceAfterNextHarvest, balanceAliceAfterFirstHarvest + pendingDividendsAliceInNextCycle1);
    // // final balance, 9 - 1 + (1 rewards token / 3), =0.3333 comes from "amountDividendToShare" divided by address(this), alice, and butler
    assertEq(balanceAliceAfterNextHarvest, initialXNeutroBalanceAlice - allocateAmountToPluginAlice + (amountDividendToShare / 3) - 1);

    vm.warp(startTime_ + 7 days);
    uint256 pendingDividendsButler = dividends.pendingDividendsAmount(address(xneutro), butler);
    vm.startPrank(butler);
    dividends.harvestAllDividends();
    vm.stopPrank();
    uint256 finalBalanceButler = xneutro.balanceOf(butler);
    assertEq(finalBalanceButler, initialXNeutroBalanceButler - allocateAmountToPluginButler + pendingDividendsButler);
    // check if the butler really can harvest the dividends
    assertGt(finalBalanceButler, initialXNeutroBalanceAlice - allocateAmountToPluginAlice);
  }

  function testHarvestAndAddRewards() external {
    _allocateToDividensPlugin(alice, allocateAmountToPluginAlice);

    uint256 amountDividendToShare = 1 ether;
    uint256 amountDividendToShareCycle2 = 2 ether;

    dividends.addDividendsToPending(address(xneutro), amountDividendToShare);
    // dividends.massUpdateDividendsInfo();
    dividends.enableDistributedToken(address(xneutro));

    // jump to startTime_ + 1 days
    vm.warp(startTime_ + 1 days);
    uint256 balanceAliceBeforeFirstHarvest = xneutro.balanceOf(alice);

    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();

    uint256 balanceAliceAfterFirstHarvest = xneutro.balanceOf(alice);
    assertGt(balanceAliceAfterFirstHarvest, balanceAliceBeforeFirstHarvest);

    // jump to startTime_ + 6 days, already harvest the first day
    vm.warp(startTime_ + 6 days);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();

    uint256 balanceAliceAfterSecondHarvest = xneutro.balanceOf(alice);
    assertGt(balanceAliceAfterSecondHarvest, balanceAliceAfterFirstHarvest);

    // add dividens for next cycle (WE NEED TO DISTRIBUTE NEXT CYCLE AMOUNT BEFORE THE CURRENT CYCLE ENDS)
    vm.warp(startTime_ + 7 days - 1);
    dividends.addDividendsToPending(address(xneutro), amountDividendToShareCycle2);

    vm.warp(startTime_ + 7 days);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();

    uint256 balanceAliceAfterThirdHarvest = xneutro.balanceOf(alice);
    assertGt(balanceAliceAfterThirdHarvest, balanceAliceAfterSecondHarvest);
    // equal because this cycle we only distribute "amountDividendToShare" amount
    // proof about the amountDividendToshare is fully distributed
    assertEq(balanceAliceAfterThirdHarvest, initialXNeutroBalanceAlice - allocateAmountToPluginAlice + amountDividendToShare); 

    vm.warp(startTime_ + 14 days);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();

    uint256 balanceAliceAfterFirstHarvestOnCycle2 = xneutro.balanceOf(alice);
    assertGt(balanceAliceAfterFirstHarvestOnCycle2, balanceAliceAfterThirdHarvest);
    assertEq(balanceAliceAfterFirstHarvestOnCycle2, balanceAliceAfterThirdHarvest + amountDividendToShareCycle2); // equal because in this cycle 2 we only distribute "amountDividendToShare2" amount

    // run out of divideds amount to distribute, so this action wont change anything
    vm.warp(startTime_ + 14 days + 1 days);
    vm.startPrank(alice);
    dividends.harvestAllDividends();
    vm.stopPrank();

    // proof about the dividends plugin not generating yield anymore
    uint256 lastBalanceAlice = xneutro.balanceOf(alice);
    assertEq(lastBalanceAlice, balanceAliceAfterFirstHarvestOnCycle2); // equal to prev cycle
  }

  function _allocateToDividensPlugin(address _who, uint256 _amount) internal {
    vm.startPrank(_who);
    xneutro.approveUsage(
      IXNeutroTokenUsage(dividends),
      0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    xneutro.allocate(address(dividends), _amount, "0x");
    vm.stopPrank();
  }

  function _approveAndConvertTokenToXNeutro(address _who, uint256 _amount) internal {
    vm.startPrank(_who);
    neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    xneutro.convert(_amount);
    vm.stopPrank();
  }

  function _approveXNeutroToDividendPlugin(address _who) internal {
    vm.startPrank(_who);
    xneutro.approve(address(dividends), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    vm.stopPrank();
  }
}
