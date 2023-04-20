// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IGiveaway.sol";
import "./GiveawayCollection.sol";

contract Giveaway is Ownable, IGiveaway {

    using Counters for Counters.Counter;
    Counters.Counter private _giveawayIDCounter;

    mapping(address => bool) public allowedTokens;
    mapping(uint256 => Giveaway) public giveaways;

    GiveawayCollection public goldCollection;
    GiveawayCollection public silverCollection;
    GiveawayCollection public bronzeCollection;

    modifier onlyActive(uint256 _giveawayID) {
        require(block.timestamp <= giveaways[_giveawayID].deadline, "Giveaway::onlyActive: This giveaway is not active.");
        _;
    }

    constructor(address _gold, address _silver, address _bronze) {
        goldCollection = GiveawayCollection(_gold);
        silverCollection = GiveawayCollection(_silver);
        bronzeCollection = GiveawayCollection(_bronze);
    }

    function createGiveaway(uint256 _deadline, bytes32 description) external onlyOwner {
        require(block.timestamp <= _deadline, "Giveaway::createGiveaway: Deadline needs to be in the future.");
        uint256 _newID = _giveawayIDCounter.current();
        address[] memory participants;

        giveaways[_newID] = Giveaway(_deadline, description, 0, participants);
        emit GiveawayCreated(_newID);
    }

    // user needs to approve this contract for the ERC20 beforehand
    function participate(address _token, uint256 _giveawayID) external onlyActive(_giveawayID) {
        require(allowedTokens[_token], "Giveaway::participate: Please deposit an allowed token.");
        // could also have admin pay for search instead of the user?

        uint256 decimals = ERC20(_token).decimals();
        // todo test differnet erc20s

        giveaways[_giveawayID].treasurySize++;

        bool found = false;
        for (uint256 i = 0; i < giveaways[_giveawayID].participants.length; i++) {
            if (giveaways[_giveawayID].participants[i] == msg.sender) {
                found = true;
                break;
            }
        }

        if (!found)
            giveaways[_giveawayID].participants.push(msg.sender);

        ERC20(_token).transferFrom(msg.sender, address(this), 1 * decimals);
        emit Participation(msg.sender, _giveawayID);
    }

    function pickWinner(uint256 _giveawayID) external onlyOwner {
        require(block.timestamp > giveaways[_giveawayID].deadline, "Giveaway::pickWinner: Giveaway has not ended yet.");

        uint256 randomNumber = 0;
        // todo get random number from chainlink

        uint256 treasurySize = giveaways[_giveawayID].treasurySize;
        address winner = giveaways[_giveawayID].participants[randomNumber];

        if (treasurySize < 500)
            bronzeCollection.mint(winner);
        else if (treasurySize < 10000)
            silverCollection.mint(winner);
        else
            goldCollection.mint(winner);

        emit WinnerPicked(_giveawayID, winner);
    }

    function getLatestGiveaway() external view returns (Giveaway memory) {
        uint256 _latestID = _giveawayIDCounter.current() - 1;
        return giveaways[_latestID];
    }

    function getAllGiveaways() external view returns (Giveaway[] memory) {
        Giveaway[] memory ret = new Giveaway[](_giveawayIDCounter.current());

        for (uint256 i = 0; i < _giveawayIDCounter.current(); i++) {
            ret[i] = giveaways[i];
        }

        return ret;
    }

    function addAllowedToken(address _newAllowedToken) external onlyOwner {
        allowedTokens[_newAllowedToken] = true;
    }

    function withdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transferFrom(address(this), _to, _amount);
        emit Withdrawal();
    }
}
