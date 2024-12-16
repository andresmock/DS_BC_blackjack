// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./C1.sol";
import "./R1.sol";

contract CardGame is CommitReveal {
    enum GameState { WaitingForPlayers, Committing, Revealing, Playing, Completed }
    GameState public state;

    struct Player {
        address addr;
        uint256 bet;
        uint8[] hand; // Dynamisches Array für Handkarten
        bool isActive;
        bool isBusted;
    }

    Player[] private players;
    uint256 public playerCount;
    uint8[] private bankHand; // Dynamisches Array für Bankhand
    address private bank;

    constructor() payable {
        bank = msg.sender;
        state = GameState.WaitingForPlayers;
    }

    modifier onlyBank() {
        require(msg.sender == bank, "Only the bank can perform this action");
        _;
    }

    modifier inState(GameState _state) {
        require(state == _state, "Invalid state for this action");
        _;
    }

    function joinGame(uint256 bet) external payable inState(GameState.WaitingForPlayers) {
        require(playerCount < 4, "Max 4 players allowed");
        require(msg.value == bet, "Bet amount mismatch");

        // Spieler mit leerem Handkarten-Array hinzufügen
        players.push(Player({
            addr: msg.sender,
            bet: bet,
            hand: new uint8[](0), //Leeres dynamisches Array initialisieren
            isActive: true,
            isBusted: false
        }));

        playerCount++;
    }

    function startCommittingPhase() external onlyBank inState(GameState.WaitingForPlayers) {
        require(playerCount > 0, "No players have joined");
        state = GameState.Committing;
    }

    function startRevealPhase() external onlyBank inState(GameState.Committing) {
        for (uint256 i = 0; i < players.length; i++) {
            require(commitments[players[i].addr] != 0, "Not all players committed");
        }
        require(commitments[bank] != 0, "Bank has not committed");
        state = GameState.Revealing;
    }


    function startGame() external onlyBank inState(GameState.Revealing) {
        uint256 bankNumber = revealedNumbers[bank];
        require(bankNumber != 0, "Bank has not revealed its number");

        for (uint256 i = 0; i < players.length; i++) {
            address playerAddr = players[i].addr;
            uint256 playerNumber = revealedNumbers[playerAddr];
            require(playerNumber != 0, "Player has not revealed their number");

            // Generiere Karten für den Spieler und füge sie zur Hand hinzu
            uint8[2] memory newCards = CardUtils.generateHand(playerNumber, bankNumber);
            players[i].hand.push(newCards[0]);
            players[i].hand.push(newCards[1]);

        }

        // Generiere Karten für die Bank und füge sie zur Bankhand hinzu
        uint8[2] memory bankCards = CardUtils.generateHand(bankNumber, bankNumber);
        bankHand.push(bankCards[0]);
        bankHand.push(bankCards[1]);

        state = GameState.Playing;
    }

        // Function to map the numeric card value to the correct Blackjack representation
    function getCardRepresentation(uint8 card) internal pure returns (string memory) {
        if (card == 1) {
            return "A";
        } else if (card >= 2 && card <= 10) {
            return uint2str(card); // Convert numbers 2-10 to string
        } else if (card == 11) {
            return "J";
        } else if (card == 12) {
            return "Q";
        } else if (card == 13) {
            return "K";
        }
        revert("Invalid card value");
    }

    // Helper function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
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
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }

    function getAllCards() external view returns (string[] memory bankCards, string[][] memory playerCards) {
        // Initialisierung des Rückgabearrays für die Karten der Bank
        bankCards = new string[](bankHand.length);

        for (uint256 i = 0; i < bankHand.length; i++) {
            bankCards[i] = getCardRepresentation(bankHand[i]); // Konvertiere die Karten der Bank
        }

        // Initialisierung des Rückgabearrays für die Karten der Spieler
        playerCards = new string[][](players.length);

        for (uint256 i = 0; i < players.length; i++) {
            // Initialisiere ein Array für die Karten des Spielers
            string[] memory playerHand = new string[](players[i].hand.length);

            for (uint256 j = 0; j < players[i].hand.length; j++) {
                playerHand[j] = getCardRepresentation(players[i].hand[j]); // Konvertiere die Karten des Spielers
            }

            // Speichere die konvertierte Hand des Spielers im entsprechenden Index
            playerCards[i] = playerHand;
        }

        return (bankCards, playerCards);
}


}
