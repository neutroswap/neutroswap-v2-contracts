// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FairAuction.sol";

contract FairAuctionFactory is Ownable {

    address[] public fairAuctions;

    event FairAuctionCreation(
        address indexed fairAuction,
        address indexed projectToken1,
        address indexed projectToken2,
        address saleToken,
        address lpToken,
        uint256 startTime,
        uint256 endTime,
        address treasury,
        uint256 hardCap,
        uint256 maxTokenToDistribute,
        uint256 minToRaise,
        uint256 capPerWallet
    );

    struct AuctionDetails {
        address projectToken1;
        address projectToken2;
        address saleToken;
        address lpToken;
        uint256 startTime;
        uint256 endTime;
        address treasury_;
        uint256 maxToDistribute1;
        uint256 maxToDistribute2;
        uint256 minToRaise;
        uint256 maxToRaise;
        uint256 capPerWallet;
    }

    function createFairAuction(AuctionDetails memory details) external onlyOwner returns (address) {
        FairAuction _fairAuction = new FairAuction(
            details.projectToken1,
            details.projectToken2,
            details.saleToken,
            details.lpToken,
            details.startTime,
            details.endTime,
            details.treasury_,
            details.maxToDistribute1,
            details.maxToDistribute2,
            details.minToRaise,
            details.maxToRaise,
            details.capPerWallet
        );

        address instance = address(_fairAuction);
        fairAuctions.push(instance);

        emit FairAuctionCreation(
            instance,
            details.projectToken1,
            details.projectToken2,
            details.saleToken,
            details.lpToken,
            details.startTime,
            details.endTime,
            details.treasury_,
            details.maxToRaise,
            details.maxToDistribute1 + details.maxToDistribute2,
            details.minToRaise,
            details.capPerWallet
        );

        return instance;
    }
}