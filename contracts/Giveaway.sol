// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IGiveaway.sol";
import "./GiveawayCollection.sol";

contract Giveaway is
VRFV2WrapperConsumerBase,
Ownable,
IGiveaway
{
    using Counters for Counters.Counter;
    Counters.Counter private _giveawayIDCounter;

    mapping(address => bool) public allowedTokens;
    mapping(uint256 => Giveaway) public giveaways;

    GiveawayCollection public goldCollection;
    GiveawayCollection public silverCollection;
    GiveawayCollection public bronzeCollection;

    mapping(uint256 => uint256) public req_giveaway_ID;

    uint32 callbackGasLimit = 150000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    modifier onlyActive(uint256 _giveawayID) {
        require(
            block.timestamp <= giveaways[_giveawayID].deadline,
            "Giveaway::onlyActive: This giveaway is not active."
        );
        _;
    }

    event RequestSent(uint256 requestId, uint32 numWords, uint256 paid);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    error InsufficientFunds(uint256 balance, uint256 paid);
    error RequestNotFound(uint256 requestId);
    error LinkTransferError(address sender, address receiver, uint256 amount);

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus)
    public s_requests;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    constructor(
        address _gold,
        address _silver,
        address _bronze,
        address _linkAddress,
        address _wrapperAddress
    )
    VRFV2WrapperConsumerBase(_linkAddress, _wrapperAddress)
    {
        goldCollection = GiveawayCollection(_gold);
        silverCollection = GiveawayCollection(_silver);
        bronzeCollection = GiveawayCollection(_bronze);
    }

    function createGiveaway(uint256 _deadline, bytes32 description) external onlyOwner {
        require(block.timestamp <= _deadline, "Giveaway::createGiveaway: Deadline needs to be in the future.");
        uint256 _newID = _giveawayIDCounter.current();
        address[] memory participants;

        giveaways[_newID] = Giveaway(_deadline, description, 0, participants, address(0));
        _giveawayIDCounter.increment();

        emit GiveawayCreated(_newID);
    }

    // user needs to approve this contract for the ERC20 beforehand
    function participate(address _token, uint256 _giveawayID) external onlyActive(_giveawayID) {
        require(allowedTokens[_token], "Giveaway::participate: Please deposit an allowed token.");

        uint256 decimals = ERC20(_token).decimals();

        giveaways[_giveawayID].treasurySize++;
        giveaways[_giveawayID].participants.push(msg.sender);

        ERC20(_token).transferFrom(msg.sender, address(this), 1 * 10 ** decimals);
        emit Participation(msg.sender, _giveawayID, _token);
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

    function mintNFTForWinner(uint256 giveawayID) public onlyOwner {
        Giveaway memory g = giveaways[giveawayID];
        require(g.winner != address(0), "Giveaway:mintNFTForWinner: Giveaway doesn't have winner!");

        uint256 treasurySize = g.treasurySize;

        if (treasurySize < 500)
            bronzeCollection.mint(g.winner);
        else if (treasurySize < 10000)
            silverCollection.mint(g.winner);
        else
            goldCollection.mint(g.winner);

        emit WinnerPicked(giveawayID, g.treasurySize, g.winner);
    }

    function pickWinner(uint256 _giveawayID) external onlyOwner {
        require(block.timestamp > giveaways[_giveawayID].deadline, "Giveaway::pickWinner: Giveaway has not ended yet.");

        uint256 numOfParticipants = giveaways[_giveawayID].participants.length;
        require(numOfParticipants > 0, "Giveaway::pickWinner: No participants in giveaway.");

        // only 1 participant => they're the winner
        if (numOfParticipants == 1) {
            giveaways[_giveawayID].winner = giveaways[_giveawayID].participants[0];
            mintNFTForWinner(_giveawayID);
            return;
        }

        uint256 reqID = requestRandomWords(callbackGasLimit, requestConfirmations, numWords);
        req_giveaway_ID[reqID] = _giveawayID;
    }

    function requestRandomWords(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) internal returns (uint256 requestId) {
        requestId = requestRandomness(
            _callbackGasLimit,
            _requestConfirmations,
            _numWords
        );
        uint256 paid = VRF_V2_WRAPPER.calculateRequestPrice(_callbackGasLimit);
        uint256 balance = LINK.balanceOf(address(this));
        if (balance < paid) revert InsufficientFunds(balance, paid);
        s_requests[requestId] = RequestStatus({
        paid : paid,
        randomWords : new uint256[](0),
        fulfilled : false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, _numWords, paid);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        RequestStatus storage request = s_requests[_requestId];
        if (request.paid == 0) revert RequestNotFound(_requestId);
        request.fulfilled = true;
        request.randomWords = _randomWords;

        uint256 _giveawayID = req_giveaway_ID[_requestId];

        // always is > 1
        uint256 participantCount = giveaways[_giveawayID].participants.length;
        uint256 winnerIndex = _randomWords[0] % participantCount;
        giveaways[_giveawayID].winner = giveaways[_giveawayID].participants[winnerIndex];

        emit RequestFulfilled(_requestId, _randomWords, request.paid);
    }

    function getNumberOfRequests() external view returns (uint256) {
        return requestIds.length;
    }

    function getRequestStatus(
        uint256 _requestId
    )
    external
    view
    returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        RequestStatus memory request = s_requests[_requestId];
        if (request.paid == 0) revert RequestNotFound(_requestId);
        return (request.paid, request.fulfilled, request.randomWords);
    }

}
