// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGiveaway {

    event Participation(address participant, uint256 giveawayID);
    event GiveawayCreated(uint256 giveawayID);
    event WinnerPicked(uint256 giveawayID, address winner);
    event Withdrawal();

    struct Giveaway {
        uint256 deadline;
        bytes32 description;
        uint256 treasurySize;
        address[] participants;
    }
}
