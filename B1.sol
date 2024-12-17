// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CardLibrary.sol";
import "./TimeOutLibrary.sol";

contract CardGame {
    enum GameState { WaitingForPlayers, Committing, Revealing, Playing, HitStand, Completed }
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
    bytes32[6] public bankHashes;
    uint256 private currentBankHashIndex = 0;



    mapping(address => bytes32) public playerHashes;
    mapping(address => uint256) public revealedNumbers;
    mapping(address => bool) public playerChoices; // Speichert die Wahl von Hit (true) oder Stand (false)
    mapping(address => bool) public hasChosen;

    bool public bankHashesSet; // Status, ob die Bank die Hash-Werte bereits gesetzt hat

    constructor() payable {
        bank = msg.sender;
        bankHashes[0] = 0x5569044719a1ec3b04d0afa9e7a5310c7c0473331d13dc9fafe143b2c4e8148a;
        bankHashes[1] = 0x8cdee82cb3ac6d59f1f417405a3eecf497b31f3d06d4c506f96deb67789f61e9;
        bankHashes[2] = 0x99ab169e1c348aec31efd8dfb67cd8c9a0b8671e1175932dda6708b0cc02a502;
        bankHashes[3] = 0x447dd11b9e568a4a39776c37476a0dc1aa52f08dec0e496bda446aacc5bded48;
        bankHashes[4] = 0x88456bed5a4300ee8dbd308a84179f780647bb3c4153152528902c7141799b04;
        bankHashes[5] = 0x0aeb49e17c56367f7bbd1ca11b9e0db05383c0d776987b6355d2dc2e7b60143e;
        state = GameState.WaitingForPlayers;
    }

    modifier onlyBank() {
        require(msg.sender == bank, "Only the bank can perform this action");
        _;
    }

    modifier onlyPlayers() {
        bool isPlayer = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].addr == msg.sender) {
                isPlayer = true;
                break;
            }
        }
        require(isPlayer, "Only participating players can perform this action");
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


    // Spieler setzen ihre Hashes
    function commitHash(bytes32 hash) external inState(GameState.Committing) {
        require(playerHashes[msg.sender] == 0, "Player hash already committed");
        playerHashes[msg.sender] = hash;
    }


    function startRevealPhase() external onlyBank inState(GameState.Committing) {

        for (uint256 i = 0; i < players.length; i++) {
            require(playerHashes[players[i].addr] != 0, "Not all players committed");
        }

        state = GameState.Revealing;
    }


    function revealNumber(uint256 number) external inState(GameState.Revealing) {
        require(revealedNumbers[msg.sender] == 0, "Number already revealed");

        if (msg.sender == bank) {
            // Bank darf nur den Hash an Index 0 aufdecken
            require(keccak256(abi.encodePacked(number)) == bankHashes[currentBankHashIndex], "Hash does not match for index 0");

            // Speichere die enthüllte Zahl für die Bank
            revealedNumbers[bank] = number;
            currentBankHashIndex++;
        } 
        
        else {
            // Für Spieler: Überprüfe das Commitment und speichere die enthüllte Zahl
            bytes32 hash = keccak256(abi.encodePacked(number));
            require(hash == playerHashes[msg.sender], "Hash does not match");

            // Speichere die enthüllte Zahl für den Spieler
            revealedNumbers[msg.sender] = number;
        }
    }


    function startGame() external onlyBank inState(GameState.Revealing) {
        uint256 bankNumber = revealedNumbers[bank];
        require(bankNumber != 0, "Bank has not revealed its number");

        for (uint256 i = 0; i < players.length; i++) {
            address playerAddr = players[i].addr;
            uint256 playerNumber = revealedNumbers[playerAddr];
            require(playerNumber != 0, "Player has not revealed their number");

            // Generiere Karten für den Spieler und füge sie zur Hand hinzu
            uint8 Card1 = CardUtils.generateHand(playerNumber, bankNumber);
            uint8 Card2 = CardUtils.generateHand(bankNumber, playerNumber);
            players[i].hand.push(Card1);
            players[i].hand.push(Card2);
        }

        // Generiere Karten für die Bank und füge sie zur Bankhand hinzu
        uint256 concatenatedNumber = 0;
        for (uint256 i = 0; i < players.length; i++) {
            concatenatedNumber = CardUtils.concatenateHand(players[i].hand) + concatenatedNumber;
        }

        uint8 bankCard = CardUtils.generateHand(concatenatedNumber, bankNumber);
        bankHand.push(bankCard);

        state = GameState.Playing;
    }


    function isPlayerActive(address playerAddr) internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].addr == playerAddr) {
                return players[i].isActive && !players[i].isBusted;
            }
        }
        return false; // Spieler wurde nicht gefunden oder ist inaktiv
    }

    function playerHit() external onlyPlayers inState(GameState.Playing) {
        require(isPlayerActive(msg.sender), "Player is not active or is busted");
        playerHitOrStand(true); // "Hit" wird gewählt
    }

    function playerStand() external onlyPlayers inState(GameState.Playing) {
        require(isPlayerActive(msg.sender), "Player is not active or is busted");

        playerHitOrStand(false); // Spieler wählt "Stand"

        // Prüfen, ob alle Spieler inaktiv oder busted sind
        bool allInactiveOrBusted = true;

        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].isActive && !players[i].isBusted) {
                allInactiveOrBusted = false;
                break;
            }
        }

        if (allInactiveOrBusted) {
            // Wechsel in die Completed-Phase
            state = GameState.Completed;

            // Die Bank zieht automatisch Karten
            generateBankCards();
        }
    }


    function playerHitOrStand(bool choice) private inState(GameState.Playing) {
        require(!hasChosen[msg.sender], "Choice already made"); // Spieler darf nur einmal wählen

        // Speichere die Wahl des Spielers
        playerChoices[msg.sender] = choice; // true = Hit, false = Stand

        // Markiere, dass der Spieler gewählt hat
        hasChosen[msg.sender] = true;

        if (!choice) {
            // Spieler hat "Stand" gewählt
            for (uint256 i = 0; i < players.length; i++) {
                if (players[i].addr == msg.sender) {
                    players[i].isActive = false; // Spieler ist nicht mehr aktiv
                    break;
                }
            }
        }
    }

    function distributeCards(uint256 randomNumber) external onlyBank inState(GameState.Playing) {
        // Überprüfe, ob alle Spieler ihre Wahl getroffen haben
        for (uint256 i = 0; i < players.length; i++) {
            require(hasChosen[players[i].addr], "Not all players have made their choice");
        }
        // Überprüfe, ob die übergebene Zahl mit dem nächsten Bank-Hash übereinstimmt
        require(currentBankHashIndex < bankHashes.length, "No more hashes available");
        require(keccak256(abi.encodePacked(randomNumber)) == bankHashes[currentBankHashIndex], "Hash does not match the next bank hash");
        currentBankHashIndex++;

        // Verteile Karten basierend auf den Entscheidungen der Spieler
        for (uint256 i = 0; i < players.length; i++) {
            Player storage player = players[i];

            if (playerChoices[player.addr] && player.isActive && !player.isBusted) { // Spieler hat "Hit" gewählt

                uint256 concatenatedHand = CardUtils.concatenateHand(player.hand); // Handkarten verketten
                uint8 newCard = CardUtils.generateHand(concatenatedHand, randomNumber);
                player.hand.push(newCard);

                // Überprüfe, ob der Spieler "busted" ist
                if (CardUtils.calculateHandValue(player.hand) > 21) {
                    player.isBusted = true;
                    player.isActive = false;
                }
            }
        }

        // Zurücksetzen der Wahl-Flags für die nächste Runde
        for (uint256 i = 0; i < players.length; i++) {
            hasChosen[players[i].addr] = false;
        }

        // Prüfe, ob das Spiel beendet ist (alle Spieler sind "busted" oder "stand")
        bool allInactive= true;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].isActive) {
                allInactive = false;
                break;
            }
        }

        if (allInactive) {
            state = GameState.Completed;
            generateBankCards();
        } 
    }

    function generateBankCards() internal {
        require(state == GameState.Completed, "Bank cards can only be drawn in Completed state");

        uint256 combinedHashInput = 0;

        // Verkette alle Spielercommits für die Zufallszahlengenerierung
        for (uint256 i = 0; i < players.length; i++) {
            combinedHashInput = uint256(keccak256(abi.encodePacked(combinedHashInput, playerHashes[players[i].addr])));
        }

        uint256 concatedBankHand = 0;

        // Die Bank zieht Karten, bis der Wert >= 17 ist oder die Bank bustet
        while (CardUtils.calculateHandValue(bankHand) < 17) {

            concatedBankHand = CardUtils.concatenateHand(bankHand) + concatedBankHand;

            uint8 newBankCard = CardUtils.generateHand(combinedHashInput, concatedBankHand);
            bankHand.push(newBankCard);

        }
    }

    function cashout() external onlyBank inState(GameState.Completed) {
        uint8 bankValue = CardUtils.calculateHandValue(bankHand);

        // Gewinne berechnen und auszahlen
        for (uint256 i = 0; i < players.length; i++) {
            Player storage player = players[i];
            uint8 playerValue = CardUtils.calculateHandValue(player.hand);

            if (player.isBusted || (bankValue <= 21 && bankValue >= playerValue)) {
                // Spieler verliert Einsatz - Bank behält den Betrag
                continue;
            } else {
                // Spieler gewinnt seinen Einsatz + gleichen Betrag als Gewinn
                uint256 payout = player.bet * 2;
                payable(player.addr).transfer(payout);
            }
        }

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

    function calculateAllCardValues() external view returns (uint8[] memory playerValues, uint8 bankValue) {
        // Array für Spielerwerte initialisieren
        playerValues = new uint8[](players.length);

        // Spielerwerte berechnen
        for (uint256 i = 0; i < players.length; i++) {
            playerValues[i] = CardUtils.calculateHandValue(players[i].hand);
        }

        // Bankwert berechnen
        bankValue = CardUtils.calculateHandValue(bankHand);

        return (playerValues, bankValue);
    }


}
