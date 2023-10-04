// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { XNeutroToken } from "../src/tokens/XNeutroToken.sol";
import { NeutroToken } from "../src/v1/NeutroToken.sol";
import { Dividends } from "../src/plugins/Dividends.sol";
import { IXNeutroTokenUsage } from "../src/interfaces/IXNeutroTokenUsage.sol";

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);
}

contract XNeutroTest is StdCheats, Test {
  NeutroToken internal neutro;
  XNeutroToken internal xneutro;
  Dividends internal dividend;
  IXNeutroTokenUsage internal idividends;

  address public constant NEUTRO_OWNER = 0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7;

  function setUp() public virtual {
    vm.createSelectFork({ urlOrAlias: "eos_evm_mainnet", blockNumber: 14_531_686 }); // fork test

    neutro = NeutroToken(0xF4bd487A8190211E62925435963D996b59a860C0);
    xneutro = new XNeutroToken(address(neutro));

    dividend = new Dividends(address(xneutro), block.timestamp);
    xneutro.updateDividendsAddress(address(dividend));
  }

  function testTokenMetadata() external {
    string memory _name = neutro.name();
    assertEq(_name, "Neutro Token");

    string memory _symbol = neutro.symbol();
    assertEq(_symbol, "NEUTRO");
  }

  function testConvertToXNeutro() external {
    address alice = address(0x100);
    uint256 initialBalanceNeutroAlice = 5 ether;
    vm.startPrank(NEUTRO_OWNER);
    neutro.transfer(alice, initialBalanceNeutroAlice);
    vm.stopPrank();

    uint256 neutroConverted = 2 ether;
    vm.startPrank(alice);
    neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    xneutro.convert(neutroConverted);
    uint256 balanceNeutroAlice = neutro.balanceOf(alice);
    assertEq(balanceNeutroAlice, initialBalanceNeutroAlice - neutroConverted);

    uint256 balanceXNeutroAlice = xneutro.balanceOf(alice);
    assertEq(balanceXNeutroAlice, neutroConverted);

    vm.expectRevert("redeem: duration too low");
    xneutro.redeem(neutroConverted, 29 days);

    xneutro.redeem(neutroConverted, 30 days);
    uint256 balanceXNeutroAfterConvertion = xneutro.balanceOf(alice);
    assertEq(balanceXNeutroAfterConvertion, balanceXNeutroAlice - neutroConverted);
    vm.stopPrank();

    uint256 redeemLength = xneutro.getUserRedeemsLength(alice);
    assertEq(redeemLength, 1);

    (uint256 allocatedAmount, uint256 redeemingAmount) = xneutro.getXNeutroBalance(alice);
    assertEq(allocatedAmount, 0);
    assertEq(redeemingAmount, neutroConverted);

    (uint256 neutroAmount, uint256 xNeutroAmount, uint256 endTime, address dividendsContract, uint256 dividendsAllocation) = xneutro.getUserRedeem(alice, 0);
    assertEq(neutroAmount, neutroConverted / 2);
    assertEq(xNeutroAmount, neutroConverted);
    assertEq(endTime, block.timestamp + 30 days);
    assertEq(dividendsContract, address(dividend));
    assertEq(dividendsAllocation, neutroConverted / 2); // 50% of redeem amount goes to dividen plugins
  }

  function testMultipleRedeem() external {
    address alice = address(0x100);
    uint256 initialBalanceNeutroAlice = 5 ether;
    vm.startPrank(NEUTRO_OWNER);
    neutro.transfer(alice, initialBalanceNeutroAlice);
    vm.stopPrank();

    uint256 redeem1Amount = 1 ether;
    uint256 redeem2Amount = 2 ether;
    uint256 redeem3Amount = 2 ether;

    vm.startPrank(alice);
    neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    xneutro.convert(redeem1Amount + redeem2Amount + redeem3Amount);
    uint256 balanceXNEUTROAfterConvertion = xneutro.balanceOf(alice);
    assertEq(balanceXNEUTROAfterConvertion , redeem1Amount + redeem2Amount + redeem3Amount);

    xneutro.redeem(redeem1Amount, 30 days);
    xneutro.redeem(redeem2Amount, 60 days);
    xneutro.redeem(redeem3Amount, 90 days);
    (uint256 allocatedAmount, uint256 redeemingAmount) = xneutro.getXNeutroBalance(alice);
    assertEq(allocatedAmount, 0);
    assertEq(redeemingAmount, redeem1Amount + redeem2Amount + redeem3Amount);

    uint256 balanceXNEUTROAfterRedeem = xneutro.balanceOf(alice);
    assertEq(balanceXNEUTROAfterRedeem , 0);

    // // COMMENT: STACK TOO DEEP :(
    // (uint256 neutroAmount1, uint256 xNEUTROAmount1, uint256 endTime1, ,) = xneutro.getUserRedeem(alice, 0);
    // assertEq(neutroAmount1, redeem1Amount / 2);
    // assertEq(xNEUTROAmount1, redeem1Amount);
    // assertEq(endTime1, block.timestamp + 30 days);

    // (uint256 neutroAmount2, uint256 xNEUTROAmount2, uint256 endTime2, , ) = xneutro.getUserRedeem(alice, 1);
    // assertEq(neutroAmount2, xneutro.getNeutroByVestingDuration(redeem2Amount, 60 days));
    // assertEq(xNEUTROAmount2, redeem2Amount);
    // assertEq(endTime2, block.timestamp + 60 days);

    // (uint256 neutroAmount3, uint256 xNEUTROAmount3, uint256 endTime3, , ) = xneutro.getUserRedeem(alice, 2);
    // assertEq(neutroAmount3, redeem3Amount);
    // assertEq(xNEUTROAmount3, redeem3Amount);
    // assertEq(endTime3, block.timestamp + 90 days);

    xneutro.cancelRedeem(0);
    xneutro.cancelRedeem(1);
    uint256 balanceXNEUTROAfterCancelRedeem = xneutro.balanceOf(alice);
    assertEq(balanceXNEUTROAfterCancelRedeem, redeem1Amount + redeem2Amount);

    // (uint256 neutroAmount3, uint256 xNEUTROAmount3, uint256 endTime3) = xneutro.getUserRedeem(alice, 0);
    // assertEq(neutroAmount3, redeem3Amount);
    // assertEq(xNEUTROAmount3, redeem3Amount);
    // assertEq(endTime3, block.timestamp + 90 days);

    vm.expectRevert("finalizeRedeem: vesting duration has not ended yet");
    xneutro.finalizeRedeem(0);

    vm.warp(block.timestamp + 90 days);
    xneutro.finalizeRedeem(0);
    uint256 balanceNEUTROAfterFinalizeRedeem = neutro.balanceOf(alice);
    uint256 balanceXNEUTROAfterFinalizeRedeem = xneutro.balanceOf(alice);

    // got back the xNeutro token after cancel redeem
    assertEq(balanceXNEUTROAfterFinalizeRedeem, redeem1Amount + redeem2Amount);
    // NEUTRO left
    assertEq(balanceNEUTROAfterFinalizeRedeem, initialBalanceNeutroAlice - redeem1Amount - redeem2Amount);
    // total NEUTRO + xNEUTRO
    assertEq(balanceNEUTROAfterFinalizeRedeem + balanceXNEUTROAfterFinalizeRedeem, initialBalanceNeutroAlice);
  }

  function testTransferWhiteListXNeutro() external {
    address alice = address(0x100);
    address bob = address(0x11);
    uint256 trfAmount = 5 ether;
    vm.startPrank(NEUTRO_OWNER);
    neutro.transfer(alice, trfAmount);
    vm.stopPrank();

    vm.startPrank(alice);
    neutro.approve(address(xneutro), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    xneutro.convert(trfAmount);
    uint256 balanceXNeutroAlice = xneutro.balanceOf(alice);
    assertEq(balanceXNeutroAlice, trfAmount);
    uint256 balanceXNeutroBob = xneutro.balanceOf(bob);
    assertEq(balanceXNeutroBob, 0);
    vm.expectRevert("transfer: not allowed");
    xneutro.transfer(bob, trfAmount);
    vm.stopPrank();

    xneutro.updateTransferWhitelist(alice, true);

    vm.startPrank(alice);
    xneutro.transfer(bob, trfAmount);
    vm.stopPrank();

    uint256 xNeutroBalanceBobAfterTransfer = xneutro.balanceOf(bob);
    assertEq(xNeutroBalanceBobAfterTransfer , trfAmount);
    uint256 xNeutroBalanceAliceAfterTransfer = xneutro.balanceOf(alice);
    assertEq(xNeutroBalanceAliceAfterTransfer, 0);

    vm.startPrank(bob);
    xneutro.transfer(alice, trfAmount);
    vm.stopPrank();

    uint256 finalxNeutroBalanceByAlice = xneutro.balanceOf(alice);
    uint256 finalxNeutroBalanceByBob = xneutro.balanceOf(bob);
    assertEq(finalxNeutroBalanceByAlice, balanceXNeutroAlice);
    assertEq(finalxNeutroBalanceByBob, balanceXNeutroBob);
  }
}
