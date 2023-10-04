// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { FairAuction } from "../src/launchpad/FairAuction.sol";
import { MockToken } from "./MockToken.sol";

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);
}

contract FairAuctionTest is StdCheats,Test {
  MockToken internal token1;
  MockToken internal xToken1;
  MockToken internal lpToken;
  MockToken internal saleToken;
  FairAuction internal fairAuction;

  //Addresses
  address treasuryAddress_ = address(0x888);
  //Address Non Whitelist
  address alice = address(0x100);
  address butler = address(0x101);

  //Address Whitelist 
  address charlie = address(0x200);
  address delta = address(0x202);
  address owner = address(0x9A5ad9bdC4FF8d154c9e14173c993d68d02c22A7);
  
  //Balances
  uint256 initialSaleTokenBalanceAlice = _convertToDecimals6(200_000 ether);
  uint256 initialSaleTokenBalanceButler = _convertToDecimals6(200_000 ether);
  uint256 initialSaleTokenBalanceCharlie = _convertToDecimals6(200_000 ether);
  uint256 initialSaleTokenBalanceDelta = _convertToDecimals6(200_000 ether);

  //Buy amount
  uint256 buyAmountByAlice = _convertToDecimals6(1 ether);
  uint256 buyAmountByButler = _convertToDecimals6(2 ether);
  uint256 buyAmountByCharlie = _convertToDecimals6(3 ether);
  uint256 buyAmountByDelta = _convertToDecimals6(4 ether);

  //TimeStamp
  uint256 startTime = block.timestamp + 1 days;
  uint256 endTime = block.timestamp + 7 days;

  function setUp() public virtual {
    token1 = new MockToken("Schrodinger Token" , "ST", address(this), 15_000 ether , 6);
    xToken1 = new MockToken("XSchrodinger Token" , "XST", address(this), 15_000 ether , 6);
    lpToken = new MockToken("LP Token", "LP", address(this), 100 ether, 18);
    saleToken = new MockToken("USDC", "USDC", address(this), _convertToDecimals6(1_000_000 ether), 6);

    saleToken.transfer(alice, initialSaleTokenBalanceAlice);
    saleToken.transfer(butler, initialSaleTokenBalanceButler);
    saleToken.transfer(charlie, initialSaleTokenBalanceCharlie);
    saleToken.transfer(delta, initialSaleTokenBalanceDelta);

    // NOTE: OWNER IS HARDCODED IN CONTRACT ITSELF, avoiding stack too deep
    fairAuction = new FairAuction(
      address(token1),
      address(xToken1),
      address(saleToken),
      address(lpToken),
      startTime,
      endTime,
      treasuryAddress_,
      15000 ether,
      15000 ether,
      200000000000,
      20000000000000,
      20000000000000
    );
  }

  function testGetRemainingTime() public {
    assertEq(fairAuction.getRemainingTime(),604800);
  }

  function testHasStartedAndEnded() public {
    assertEq(fairAuction.hasStarted(),false);
    assertEq(fairAuction.hasEnded(),false);
    vm.warp(startTime);
    assertEq(fairAuction.hasStarted(),true);
    assertEq(fairAuction.hasEnded(),false);
    vm.warp(endTime);
    assertEq(fairAuction.hasStarted(),true);
    assertEq(fairAuction.hasEnded(),true);
  }

  function testTokenTransfer() public {
    assertEq(fairAuction.projectTokensToDistribute(),0);
    assertEq(fairAuction.projectTokens2ToDistribute(),0);
    
    token1.transfer(address(fairAuction), 15_000 ether);
    assertEq(token1.balanceOf(address(fairAuction)),15_000 ether);
    xToken1.transfer(address(fairAuction), 15_000 ether);
    assertEq(xToken1.balanceOf(address(fairAuction)),15_000 ether);
  }

  function testBuyWithConditionAndDistribute() public {
    // H-1 day before sale , Sale is not active
    vm.warp(startTime - 1);
    vm.expectRevert("isActive: sale is not active");
    _buyToken(alice, buyAmountByAlice);

    vm.warp(startTime);
    // Revert because the contract didnt have any esper
    vm.expectRevert("isActive: sale not filled");
    _buyToken(alice, buyAmountByAlice);
    
    // Transfer esper to the contract so can distribute token
    token1.transfer(address(fairAuction), 15_000 ether);
    xToken1.transfer(address(fairAuction), 15_000 ether);

    // Approve sale token to this address
    _approveSaleTokenToFairAuction(alice);

    // Buy Token but user not whitelisted
    assertEq(fairAuction.whitelistOnly(),true);
    vm.expectRevert("buy: not whitelisted");
    _buyToken(alice, buyAmountByAlice);

    // Set Paused to whitelist
    vm.startPrank(owner);
    fairAuction.setWhitelistOnly(false);
    vm.stopPrank();
    assertEq(fairAuction.whitelistOnly(),false);

    //Buy Token
    _buyToken(alice, buyAmountByAlice);
    //Check Balance of alice
    assertEq(saleToken.balanceOf(alice), initialSaleTokenBalanceAlice - buyAmountByAlice);
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , buyAmountByAlice);

    uint256 remainingTime = fairAuction.getRemainingTime();
    assertEq(remainingTime, fairAuction.END_TIME() - block.timestamp);

    //Check total raised
    assertEq(fairAuction.totalRaised(), buyAmountByAlice);

    uint256 tokenToDistributeAfterAliceBuy = fairAuction.tokensToDistribute();
    // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokenToDistributeAfterAliceBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokenToDistributeAfterAliceBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * buyAmountByAlice) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    
    (
      uint256 contribution,
      ,
      ,
    ) = fairAuction.userInfo(alice);
    assertEq(contribution , buyAmountByAlice);
    
    //Owner Pause
    vm.startPrank(owner);
    assertEq(fairAuction.isPaused(),false);
    fairAuction.setPause(true);
    assertEq(fairAuction.isPaused(),true);
    vm.stopPrank();

    //Try to Buy when sale is paused
    vm.expectRevert("isNotPaused: sale is paused");
    _buyToken(alice, buyAmountByAlice);

    //Revert withdraw / burn because sale haven't closed
    vm.startPrank(owner);
    vm.expectRevert("withdrawUnsoldTokens: presale has not ended");
    fairAuction.withdrawUnsoldTokens();
    vm.stopPrank();

    //Revert because sale is closed
    vm.warp(endTime);
    vm.expectRevert("isActive: sale is not active");
    _buyToken(alice, buyAmountByAlice);

    //Burn or withdraw
    vm.startPrank(owner);
    fairAuction.withdrawUnsoldTokens();
    vm.stopPrank();
    assertEq(token1.balanceOf(owner),fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() - fairAuction.projectTokensToDistribute());
    assertEq(xToken1.balanceOf(owner),fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE() - fairAuction.projectTokens2ToDistribute());

    //cannot Burn or withdraw twice
    vm.startPrank(owner);
    vm.expectRevert("withdrawUnsoldTokens: already burnt");
    fairAuction.withdrawUnsoldTokens();
    vm.stopPrank();

  }

  function testSetWhitelistAndBuyWithClaim() public {
    
    // Transfer esper to the contract so can distribute token
    token1.transfer(address(fairAuction), 15_000 ether);
    xToken1.transfer(address(fairAuction), 15_000 ether);

    //Approval Non Whitelist
    _approveSaleTokenToFairAuction(alice);
    _approveSaleTokenToFairAuction(butler);

    //Approval Whitelist
    _approveSaleTokenToFairAuction(charlie);
    _approveSaleTokenToFairAuction(delta);
    
    //Try to Claim when not buy
    vm.warp(endTime);
    vm.expectRevert("claim: zero contribution");
    _claim(alice);
    vm.expectRevert("claim: zero contribution");
    _claim(butler);
    vm.expectRevert("claim: zero contribution");
    _claim(charlie);
    vm.expectRevert("claim: zero contribution");
    _claim(delta);

    //Owner set whitelist to charlie & delta   
    FairAuction.WhitelistSettings[] memory whitelistUser = new FairAuction.WhitelistSettings[](2);
    FairAuction.WhitelistSettings memory whitelistCharlie = FairAuction.WhitelistSettings(
      charlie,
      true,
      50 ether
    );
    FairAuction.WhitelistSettings memory whitelistDelta = FairAuction.WhitelistSettings(
      delta,
      true,
      50 ether
    );
    whitelistUser[0] = whitelistCharlie;
    whitelistUser[1] = whitelistDelta;

    vm.startPrank(owner);
    fairAuction.setUsersWhitelist(whitelistUser);
    vm.stopPrank();

    // Check if data is inserted
    (
      ,
      bool isWhitelistCharlie,
      uint256 charlieWhitelistCap
      ,
    ) = fairAuction.userInfo(charlie);
    assertEq(isWhitelistCharlie,true);
    assertEq(charlieWhitelistCap, 50 ether);

    (
      ,
      bool isWhitelistDelta,
      uint256 deltaWhitelistCap
      ,
    ) = fairAuction.userInfo(delta);
    assertEq(isWhitelistDelta,true);
    assertEq(deltaWhitelistCap, 50 ether);
    
    //Onwer set Whitelist Only
    vm.startPrank(owner);
    fairAuction.setWhitelistOnly(true);
    assertEq(fairAuction.whitelistOnly(),true);
    vm.stopPrank();

    //Set to Start time || whitelistOnly is = true
    vm.warp(startTime);

    //Public Buy Token
    vm.expectRevert("buy: not whitelisted");
    _buyToken(alice, buyAmountByAlice);

    vm.expectRevert("buy: not whitelisted");
    _buyToken(butler, buyAmountByButler);

    //Whitelisted buy Tokens
    //1
    _buyToken(charlie, buyAmountByCharlie);
    // Check Balance of charlie
    assertEq(saleToken.balanceOf(charlie), initialSaleTokenBalanceCharlie - buyAmountByCharlie);
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , buyAmountByCharlie);
    // Check total raised
    assertEq(fairAuction.totalRaised(), buyAmountByCharlie);
    uint256 tokenToDistributeAfterCharlieBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokenToDistributeAfterCharlieBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokenToDistributeAfterCharlieBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * buyAmountByCharlie) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionCharlie,
      ,
      ,
    ) = fairAuction.userInfo(charlie);
    assertEq(contributionCharlie , buyAmountByCharlie);

    //2
    //Whitelisted buy Tokens
    _buyToken(delta, buyAmountByDelta);
    // Check Balance of Delta
    assertEq(saleToken.balanceOf(delta), initialSaleTokenBalanceDelta - buyAmountByDelta);
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , buyAmountByDelta + buyAmountByCharlie);
    // Check total raised
    assertEq(fairAuction.totalRaised(), buyAmountByDelta + buyAmountByCharlie);
    uint256 tokenToDistributeAfterDeltaBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokenToDistributeAfterDeltaBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokenToDistributeAfterDeltaBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * (buyAmountByDelta + buyAmountByCharlie)) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionDelta,
      ,
      ,
    ) = fairAuction.userInfo(delta);
    assertEq(contributionDelta , buyAmountByDelta);

    //Owner set Whitelist Only to false
    vm.startPrank(owner);
    fairAuction.setWhitelistOnly(false);
    assertEq(fairAuction.whitelistOnly(),false);
    vm.stopPrank();

    //Public buy
    //3
    //Whitelisted buy Tokens
    _buyToken(alice, buyAmountByAlice);
    // Check Balance of Alice
    assertEq(saleToken.balanceOf(alice), initialSaleTokenBalanceAlice - buyAmountByAlice);
    //Accumulation
    uint256 accumulation3 = buyAmountByCharlie + buyAmountByDelta + buyAmountByAlice;
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , accumulation3);
    // Check total raised
    assertEq(fairAuction.totalRaised(), accumulation3);
    uint256 tokenToDistributeAfterAliceBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokenToDistributeAfterAliceBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokenToDistributeAfterAliceBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * (accumulation3)) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionAlice,
      ,
      ,
    ) = fairAuction.userInfo(alice);
    assertEq(contributionAlice , buyAmountByAlice);

    //4
    //Whitelisted buy Tokens
    _buyToken(butler, buyAmountByButler);
    // Check Balance of Butler
    assertEq(saleToken.balanceOf(butler), initialSaleTokenBalanceButler - buyAmountByButler);
    //Accumulation
    uint256 accumulation4 = buyAmountByCharlie + buyAmountByDelta + buyAmountByAlice + buyAmountByButler;
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , accumulation4);
    // Check total raised
    assertEq(fairAuction.totalRaised(), accumulation4);
    uint256 tokenToDistributeAfterButlerBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokenToDistributeAfterButlerBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokenToDistributeAfterButlerBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * (accumulation4)) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionButler,
      ,
      ,
    ) = fairAuction.userInfo(butler);
    assertEq(contributionButler , buyAmountByButler);

    //Whitelist try to buy again in public

    //5
    //Whitelisted buy Tokens
    _buyToken(charlie, buyAmountByCharlie);
    // Check Balance of Charlie
    assertEq(saleToken.balanceOf(charlie), initialSaleTokenBalanceCharlie - (buyAmountByCharlie * 2));
    //Accumulation
    uint256 accumulation5 = (buyAmountByCharlie * 2) + buyAmountByDelta + buyAmountByAlice + buyAmountByButler;
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , accumulation5);
    // Check total raised
    assertEq(fairAuction.totalRaised(), accumulation5);
    uint256 tokentoDistributeAfterCharlieSecondBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokentoDistributeAfterCharlieSecondBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokentoDistributeAfterCharlieSecondBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * (accumulation5)) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionSecondCharlie,
      ,
      ,
    ) = fairAuction.userInfo(charlie);
    assertEq(contributionSecondCharlie , (buyAmountByCharlie * 2));

    //5
    //Whitelisted buy Tokens
    _buyToken(delta, buyAmountByDelta);
    // Check Balance of Delta
    assertEq(saleToken.balanceOf(delta), initialSaleTokenBalanceDelta - (buyAmountByDelta * 2));
    //Accumulation
    uint256 accumulation6 = (buyAmountByCharlie * 2) + (buyAmountByDelta * 2) + buyAmountByAlice + buyAmountByButler;
    //Treasury balance should be increased too
    assertEq(saleToken.balanceOf(fairAuction.treasury()) , accumulation6);
    // Check total raised
    assertEq(fairAuction.totalRaised(), accumulation6);
    uint256 tokentoDistributeAfterDeltaSecondBuy = fairAuction.tokensToDistribute();
    // // in price discovery, if the totalRaised is over the MIN_TOTAL_RAISED_FOR_MAX_token, we will distribute the full amount of MAX_token_TO_DISTRIBUTE
    assertEq(tokentoDistributeAfterDeltaSecondBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * fairAuction.totalRaised()) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    assertEq(tokentoDistributeAfterDeltaSecondBuy, ((fairAuction.MAX_PROJECT_TOKENS_TO_DISTRIBUTE() + fairAuction.MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE()) * (accumulation6)) / fairAuction.MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN());
    (
      uint256 contributionSecondDelta,
      ,
      ,
    ) = fairAuction.userInfo(delta);
    assertEq(contributionSecondDelta , (buyAmountByDelta * 2));


    //Users Claim
    //Alice
    uint256 balanceSchrodingerByAliceBeforeClaim = token1.balanceOf(alice);
    assertEq(token1.balanceOf(alice), 0 ether);
    uint256 balanceXSchrodingerByAliceBeforeClaim = xToken1.balanceOf(alice);
    assertEq(xToken1.balanceOf(alice), 0 ether);
    uint256 balanceSchrodingerByButlerBeforeClaim = token1.balanceOf(butler);
    assertEq(token1.balanceOf(butler), 0 ether);
    uint256 balanceXSchrodingerByButlerBeforeClaim = xToken1.balanceOf(butler);
    assertEq(xToken1.balanceOf(butler), 0 ether);
    uint256 balanceSchrodingerByCharlieBeforeClaim = token1.balanceOf(charlie);
    assertEq(token1.balanceOf(charlie), 0 ether);
    uint256 balanceXSchrodingerByCharlieBeforeClaim = xToken1.balanceOf(charlie);
    assertEq(xToken1.balanceOf(charlie), 0 ether);
    uint256 balanceSchrodingerByDeltaBeforeClaim = token1.balanceOf(delta);
    assertEq(token1.balanceOf(delta), 0 ether);
    uint256 balanceXSchrodingerByDeltaBeforeClaim = xToken1.balanceOf(delta);
    assertEq(xToken1.balanceOf(delta), 0 ether);

    vm.warp(endTime);
    _claim(alice);
    _claim(butler);
    _claim(charlie);
    _claim(delta);

    //Check Balance After Claim
    assertEq(token1.balanceOf(alice),0.075 ether);
    assertEq(xToken1.balanceOf(alice),0.075 ether);
    assertEq(token1.balanceOf(butler),0.15 ether);
    assertEq(xToken1.balanceOf(butler),0.15 ether);
    assertEq(token1.balanceOf(charlie),0.45 ether);
    assertEq(xToken1.balanceOf(charlie),0.45 ether);
    assertEq(token1.balanceOf(delta),0.6 ether);
    assertEq(xToken1.balanceOf(delta),0.6 ether);

    assertGt(token1.balanceOf(alice), balanceSchrodingerByAliceBeforeClaim);
    assertGt(xToken1.balanceOf(alice), balanceXSchrodingerByAliceBeforeClaim);
    assertGt(token1.balanceOf(butler), balanceSchrodingerByButlerBeforeClaim);
    assertGt(xToken1.balanceOf(butler), balanceXSchrodingerByButlerBeforeClaim);
    assertGt(token1.balanceOf(charlie), balanceSchrodingerByCharlieBeforeClaim);
    assertGt(xToken1.balanceOf(charlie), balanceXSchrodingerByCharlieBeforeClaim);
    assertGt(token1.balanceOf(delta), balanceSchrodingerByDeltaBeforeClaim);
    assertGt(xToken1.balanceOf(delta), balanceXSchrodingerByDeltaBeforeClaim);
    
    vm.expectRevert("claim: already claimed");
    _claim(alice);
    vm.expectRevert("claim: already claimed");
    _claim(butler);
    vm.expectRevert("claim: already claimed");
    _claim(charlie);
    vm.expectRevert("claim: already claimed");
    _claim(delta);

  }

  function testWithdraw() public {
    //Schrodinger transfer to contract
    token1.transfer(address(fairAuction), 15_000 ether);
    assertEq(token1.balanceOf(address(fairAuction)),15_000 ether);
    xToken1.transfer(address(fairAuction), 15_000 ether);
    assertEq(xToken1.balanceOf(address(fairAuction)),15_000 ether);

    vm.startPrank(owner);
    fairAuction.emergencyWithdrawFunds(address(token1), 15_000 ether);
    assertEq(token1.balanceOf(address(fairAuction)),0 ether);
    fairAuction.emergencyWithdrawFunds(address(xToken1), 15_000 ether);
    assertEq(xToken1.balanceOf(address(fairAuction)),0 ether);
    vm.stopPrank();

  }

  // for easier read the test
  function _convertToDecimals6(uint256 _amount) internal pure returns (uint256) {
    return _amount / 10**12;
  }

  function _approveSaleTokenToFairAuction(address _who) internal {
    vm.startPrank(_who);
    saleToken.approve(address(fairAuction), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    vm.stopPrank();
  }

  function _buyToken(address _who, uint256 _amount) internal {
    vm.startPrank(_who);
    fairAuction.buy(_amount);
    vm.stopPrank();
  }

  function _claim(address _who) internal {
    vm.startPrank(_who);
    fairAuction.claim();
    vm.stopPrank();
  }
}