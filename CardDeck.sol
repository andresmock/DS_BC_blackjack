// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CardDeck {
    uint8[] internal deck;

    constructor() {
        resetDeck();
    }

    function resetDeck() internal {
        delete deck; // Leert das Deck
        for (uint8 i = 1; i <= 52; i++) {
            deck.push(i); // Fügt Karten von 1 bis 52 hinzu
        }
    }

    function shuffleDeck() internal {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1))));
        for (uint256 i = 0; i < deck.length; i++) {
            uint256 swapIndex = seed % deck.length;
            (deck[i], deck[swapIndex]) = (deck[swapIndex], deck[i]); // Tausche Karten
            seed = uint256(keccak256(abi.encodePacked(seed))); // Aktualisiere Seed
        }
    }

    function drawCard() internal returns (uint8) {
        require(deck.length > 0, "No cards left in the deck");
        uint8 card = deck[deck.length - 1];
        deck.pop(); // Entfernt die gezogene Karte
        return card;
    }

    function getHandValue(uint8[] memory hand) internal pure returns (uint8) {
        uint8 value = 0;
        uint8 aces = 0;

        for (uint256 i = 0; i < hand.length; i++) {
            uint8 cardValue = hand[i] % 13; // Kartenwert (1–13)
            if (cardValue > 10) cardValue = 10; // Bildkarten zählen 10
            if (cardValue == 1) aces++; // Ass
            value += cardValue;
        }

        while (value <= 11 && aces > 0) {
            value += 10; // Ass zählt 11, wenn möglich
            aces--;
        }

        return value;
    }
}