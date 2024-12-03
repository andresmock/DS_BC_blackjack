// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Randomness {
    function generateRandomNumber(uint256 range) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, blockhash(block.number - 1)))) % range;
    }
}
