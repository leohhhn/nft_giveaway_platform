// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GiveawayCollection is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIDCounter;

    address public owner;
    address public giveawayContract;

    modifier whitelistedUsers(){
        require(msg.sender == owner || msg.sender == giveawayContract, "Not allowed");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        owner = msg.sender;
    }

    function updateGiveaway(address _giveawayContract) external whitelistedUsers {
        giveawayContract = _giveawayContract;
    }

    function mint(address _to) external whitelistedUsers {
        uint256 _newID = _tokenIDCounter.current();
        _tokenIDCounter.increment();
        _mint(_to, _newID);
    }
}