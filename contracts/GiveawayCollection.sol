// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IGiveaway.sol";

contract GiveawayCollection is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIDCounter;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    }

    function mint(address _to) external onlyOwner {
        uint256 _newID = _tokenIDCounter.current();
        _tokenIDCounter.increment();
        _mint(_to, _newID);
    }
}