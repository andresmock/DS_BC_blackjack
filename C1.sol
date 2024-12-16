// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CardUtils {
    uint256 constant RANK_COUNT = 13;

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

    // Function to generate a hand for a Blackjack game
    function generateHand(uint256 playerNumber, uint256 bankNumber) external pure returns (string[2] memory) {
        uint8 card1 = uint8(uint256(keccak256(abi.encodePacked(playerNumber, bankNumber))) % RANK_COUNT + 1);
        uint8 card2 = uint8(uint256(keccak256(abi.encodePacked(bankNumber, playerNumber))) % RANK_COUNT + 1);

        string[2] memory hand = [
            getCardRepresentation(card1),
            getCardRepresentation(card2)
        ];

        return hand;
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

    // Function to calculate the value of a Blackjack hand
    function calculateHandValue(uint8[2] memory cards) external pure returns (uint8) {
        uint8 totalValue = 0;
        uint8 aceCount = 0;

        for (uint8 i = 0; i < cards.length; i++) {
            uint8 card = cards[i];
            if (card >= 2 && card <= 10) {
                totalValue += card; // Add the numeric value of the card
            } else if (card >= 11 && card <= 13) {
                totalValue += 10; // Face cards count as 10
            } else if (card == 1) {
                aceCount += 1; // Count Aces separately
                totalValue += 11; // Initially count each Ace as 11
            }
        }

        // Adjust for Aces if totalValue exceeds 21
        while (totalValue > 21 && aceCount > 0) {
            totalValue -= 10; // Count an Ace as 1 instead of 11
            aceCount -= 1;
        }

        return totalValue;
    }
}
