// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

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
        s_lastTimeStamp= block.timestamp;
        i_interval= interval;
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

    function checkUpkeep(bytes calldata /* checkData*/) external {
        //checking if the s_raffleState is open
        bool isOpen = (RaffleState.OPEN == s_raffleState) ;
       bool timePassed= (block.timestamp - s_lastTimeStamp)>interval;
       bool hasPlayers = (s_players.length > 0) ;
       bool hasBalance =(address(this).balance > 0);
         bool upKeepNeeded = (isOpen && hasPlayers && hasBalance && timePassed ) ;
             }


    function requestRandomWinner() external {
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
        s_players = new address payable [](0)

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

    function performUpkeep(bytes calldata performData) external override {}
}
