// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CardUtils {
    uint256 constant RANK_COUNT = 13;


    // Function to generate a hand for a Blackjack game
    function generateHand(uint256 playerNumber, uint256 bankNumber) external pure returns (uint8[2] memory) {
        uint8 card1 = uint8(uint256(keccak256(abi.encodePacked(playerNumber, bankNumber))) % RANK_COUNT + 1);
        uint8 card2 = uint8(uint256(keccak256(abi.encodePacked(bankNumber, playerNumber))) % RANK_COUNT + 1);

        return [card1, card2];
    }


    // Function to calculate the value of a Blackjack hand
    function calculateHandValue(uint8[] memory cards) external pure returns (uint8) {
        uint8 totalValue = 0;
        uint8 aceCount = 0;

        for (uint8 i = 0; i < cards.length; i++) {
            uint8 card = cards[i];
            if (card >= 2 && card <= 10) {
                totalValue += card; // Numerische Kartenwerte hinzufügen
            } else if (card >= 11 && card <= 13) {
                totalValue += 10; // Bildkarten zählen als 10
            } else if (card == 1) {
                aceCount += 1; // Aces separat zählen
                totalValue += 11; // Zunächst zählt ein Ass als 11
            }
        }

        // Anpassung der Ass-Werte, falls Gesamtwert 21 übersteigt
        while (totalValue > 21 && aceCount > 0) {
            totalValue -= 10; // Ein Ass wird als 1 statt 11 gezählt
            aceCount -= 1;
        }

        return totalValue;
    }

    function concatenateHand(uint8[] memory hand) internal pure returns (uint256) {
        uint256 concatenated;
        for (uint256 i = 0; i < hand.length; i++) {
            concatenated = concatenated * 100 + hand[i]; // Multipliziere mit 100, um Platz für zweistellige Kartenwerte zu schaffen
        }
        return concatenated;
    }


    // Function to simulate a "hit" for a player
    function hit(uint256 playerNumber, uint256 randomNumber) external pure returns (uint8) {

        // Combine the concatenated player number and the random number to generate a new card
        uint8 newCard = uint8(uint256(keccak256(abi.encodePacked(playerNumber, randomNumber))) % RANK_COUNT + 1);

        return newCard;
    }

}
