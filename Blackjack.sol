// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    Player[] private players;
    uint256 public playerCount;
    uint8[] private bankHand; // Hand der Bank
    address private bank;
    uint8[] private lastBankHand; // Speichert die gezogenen Karten der Bank
    address[] private lastWinners; // Speichert die Gewinneradressen


    constructor() payable {
        bank = msg.sender;
    }

    function joinGame(uint256 bet) external payable {
        require(playerCount < 4, "Max 4 players allowed");
        require(msg.value == bet, "Bet amount mismatch");

        players.push(Player({
            addr: msg.sender,
            bet: bet,
            hand: new uint8[](0),
            isActive: true,
            isBusted: false
        }));

        playerCount++;
    }

    function startGame() external {
        require(playerCount > 0, "No players in the game");
        shuffleDeck();

        for (uint256 i = 0; i < players.length; i++) {
            players[i].hand.push(drawCard());
            players[i].hand.push(drawCard());
        }
        bankHand.push(drawCard());
        bankHand.push(drawCard());
    }

    function formatHand(uint8[] memory hand, string memory prefix) internal pure returns (string memory) {
        string memory handString = prefix;

        for (uint256 i = 0; i < hand.length; i++) {
            uint8 cardValue = hand[i] % 13;
            if (cardValue == 0) {
                cardValue = 13; // K
            }

            string memory cardSymbol;
            if (cardValue == 1) {
                cardSymbol = "A";
            } else if (cardValue == 11) {
                cardSymbol = "J";
            } else if (cardValue == 12) {
                cardSymbol = "Q";
            } else if (cardValue == 13) {
                cardSymbol = "K";
            } else {
                cardSymbol = uint2str(cardValue);
            }

            handString = string(abi.encodePacked(handString, cardSymbol));

            if (i < hand.length - 1) {
                handString = string(abi.encodePacked(handString, ", "));
            }
        }

        return handString;
    }

    function getAllHands() external view returns (string[] memory) {
        string[] memory formattedHands = new string[](players.length + 1);

        // Bankhand formatieren
        formattedHands[0] = formatHand(bankHand, "Bank: ");

        // Spielerhände formatieren
        for (uint256 i = 0; i < players.length; i++) {
            formattedHands[i + 1] = formatHand(players[i].hand, string(abi.encodePacked("Player ", uint2str(i + 1), ": ")));
        }

        return formattedHands;
    }

    function hit() external {
        uint256 playerIndex = findPlayerIndex(msg.sender);
        require(playerIndex != type(uint256).max, "You are not a player");

        require(players[playerIndex].isActive, "Player is not active");
        require(!players[playerIndex].isBusted, "Player is already busted");

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

    event BankCardDrawn(uint8 card);
    event GameResult(address winner, uint8 score);

    string public LastBankHand; // vorher: formattedLastBankHand
    string public Winners;      // vorher: formattedLastWinners

    function determineWinner() external returns (string memory, address[] memory) {
        uint8 bankScore = getHandValue(bankHand);
        delete lastWinners;

        while (bankScore < 17) {
            uint8 card = drawCard();
            bankHand.push(card);
            bankScore = getHandValue(bankHand);
            emit BankCardDrawn(card);
        }

        // Bankhand formatieren
        lastBankHand = bankHand;
        LastBankHand = formatHand(lastBankHand, "Last Bank Hand: ");

        for (uint256 i = 0; i < players.length; i++) {
            uint8 playerScore = getHandValue(players[i].hand);
            if (!players[i].isBusted && (playerScore > bankScore || bankScore > 21)) {
                payable(players[i].addr).transfer(players[i].bet * 2);
                lastWinners.push(players[i].addr);
                emit GameResult(players[i].addr, playerScore);
            }
        }

        Winners = formatWinners(lastWinners);

        resetGame();

        return (LastBankHand, lastWinners);
    }

    function formatWinners(address[] memory winners) internal view returns (string memory) {
        uint256 nonBankCount = 0;
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i] != bank) {
                nonBankCount++;
            }
        }

        if (nonBankCount == 0) {
            return "No players won.";
        }

        string memory result = "";
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i] != bank) {
                uint256 playerIndex = findPlayerIndex(winners[i]);
                if (playerIndex != type(uint256).max) {
                    string memory playerName = string(abi.encodePacked("Player ", uint2str(playerIndex + 1)));
                    if (bytes(result).length == 0) {
                        result = playerName;
                    } else {
                        result = string(abi.encodePacked(result, ", ", playerName));
                    }
                }
            }
        }

        return result;
    }

    function findPlayerIndex(address playerAddress) internal view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].addr == playerAddress) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function resetGame() internal {
        delete players;
        delete bankHand;
        playerCount = 0;
        resetDeck();
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }
}
