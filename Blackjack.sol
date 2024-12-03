// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importiere die anderen Contracts
import "./CardDeck.sol";
import "./Randomness.sol";

contract Blackjack is CardDeck, Randomness {
    struct Player {
        address addr;
        uint256 bet;
        uint8[] hand;
        bool isActive;
        bool isBusted;
    }

    Player[] public players;
    uint256 public playerCount;
    address public bank;

    constructor() {
        bank = msg.sender; // Derjenige, der den Contract deployt, ist die Bank
    }

    function joinGame(uint256 bet) external payable {
        require(playerCount < 4, "Max 4 players allowed");
        require(msg.value == bet, "Bet amount mismatch");
        players.push(Player(msg.sender, bet, new uint8ue, false));
        playerCount++;
    }

    function startGame() external {
        require(playerCount > 0, "No players in the game");
        shuffleDeck();
        for (uint256 i = 0; i < players.length; i++) {
            players[i].hand.push(drawCard());
            players[i].hand.push(drawCard());
        }
    }

    function hit(uint256 playerIndex) external {
        require(msg.sender == players[playerIndex].addr, "Not your turn");
        require(players[playerIndex].isActive, "Player is not active");
        uint8 card = drawCard();
        players[playerIndex].hand.push(card);

        if (getHandValue(players[playerIndex].hand) > 21) {
            players[playerIndex].isBusted = true;
            players[playerIndex].isActive = false;
        }
    }

    function stand(uint256 playerIndex) external {
        require(msg.sender == players[playerIndex].addr, "Not your turn");
        players[playerIndex].isActive = false;
    }

    function determineWinner() external {
        uint8 bankScore = getHandValue(players[0].hand); // Bank spielt hier
        for (uint256 i = 1; i < players.length; i++) {
            uint8 playerScore = getHandValue(players[i].hand);
            if (!players[i].isBusted && (playerScore > bankScore || bankScore > 21)) {
                payable(players[i].addr).transfer(players[i].bet * 2);
            }
        }
        resetGame();
    }

    function resetGame() internal {
        delete players;
        playerCount = 0;
        resetDeck();
    }
}
