// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author King Julien
 * @notice This contract is for a decentralised raffle lottery
 * @dev This implements chainlink Keepers and chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    //state variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Lottery Variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    //Errors
    error Raffle__NotEnoughEthEntered();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    //events
    event Raffle_Entered(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed WinnerPicked);

    //making the centrace fee customizeable
    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    // functions
    function enterRaffle() public payable {
        //making sure the player has enough eth
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        //pushing the player to the player array
        s_players.push(payable(msg.sender));

        //events
        emit Raffle_Entered(msg.sender);
    }

    /**
     * @dev This is the function the chainlink nodes needed to perform the `upkeepNeeded` to return true
     */

    function checkUpkeep(
        bytes memory /* checkData*/
    )
        public
        override
        returns (bool upKeepNeeded, bytes memory /*performData*/)
    {
        //checking if the s_raffleState is open
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upKeepNeeded = (isOpen && hasPlayers && hasBalance && timePassed);
    }

    function performUpkeep(bytes calldata /* checkData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //getting one random words,mod the length of the players
        uint256 indeOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indeOfWinner];
        s_recentWinner = recentWinner;

        //opening the raffle state for entry after winner has been picked
        s_raffleState = RaffleState.OPEN;
        //restarting the raffle array to
        s_players = new address payable[](0);
        //resetting the timeStamp
        s_lastTimeStamp = block.timestamp;

        //sending the money to the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    // View Function
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
