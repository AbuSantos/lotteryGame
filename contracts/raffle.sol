// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract raffle {
    //state variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    error Raffle_NotEnoughEthEntered();

    //events
    event Raffle_Entered(address indexed player);

    //making the centrace fee customizeable
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    // functions
    function enterRaffle() public payable {
        //making sure the player has enough eth
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthEntered();
        }
        //pushing the player to the player array
        s_players.push(payable(msg.sender));

        //events
        emit Raffle_Entered(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
