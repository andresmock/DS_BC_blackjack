// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommitReveal {
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public revealedNumbers;

    function commitHash(bytes32 hash) external {
        require(commitments[msg.sender] == 0, "Hash already committed");
        commitments[msg.sender] = hash;
    }

    function revealNumber(uint256 number) external {
        require(commitments[msg.sender] != 0, "No hash committed");
        require(revealedNumbers[msg.sender] == 0, "Number already revealed");

        // Überprüfe das Commitment
        bytes32 hash = keccak256(abi.encodePacked(number));
        require(hash == commitments[msg.sender], "Hash does not match");

        // Speichere die enthüllte Zahl
        revealedNumbers[msg.sender] = number;
    }
}
