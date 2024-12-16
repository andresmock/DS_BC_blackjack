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
        string[] hand; // Dynamisches Array für Handkarten
        bool isActive;
        bool isBusted;
    }

    Player[] private players;
    uint256 public playerCount;
    string[] private bankHand; // Dynamisches Array für Bankhand
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
            hand: new string[](0), //Leeres dynamisches Array initialisieren
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
            string[2] memory newCards = CardUtils.generateHand(playerNumber, bankNumber);
            players[i].hand.push(newCards[0]);
            players[i].hand.push(newCards[1]);
            
        }

        // Generiere Karten für die Bank und füge sie zur Bankhand hinzu
        string[2] memory bankCards = CardUtils.generateHand(bankNumber, bankNumber);
        bankHand.push(bankCards[0]);
        bankHand.push(bankCards[1]);

        state = GameState.Playing;
    }

    function getAllCards() external view returns (string[] memory bankCards, string[][] memory playerCards) {
    // Rückgabe der Karten der Bank
    bankCards = bankHand;

    // Initialisierung des Rückgabearrays für die Karten der Spieler
    playerCards = new string[][](players.length);

    for (uint256 i = 0; i < players.length; i++) {
        // Speichere die Hand des Spielers im entsprechenden Index
        playerCards[i] = players[i].hand;
    }

    return (bankCards, playerCards);
}


}
