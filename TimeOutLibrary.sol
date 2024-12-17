// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TimeoutUtils {
    uint256 public constant ACTION_TIMEOUT = 5 minutes;

    /// Berechnet das neue Timeout
    function calculateNewDeadline() internal view returns (uint256) {
        return block.timestamp + ACTION_TIMEOUT;
    }

    /// Prüft, ob das Timeout überschritten wurde
    function hasTimeoutPassed(uint256 actionDeadline) internal view returns (bool) {
        return block.timestamp > actionDeadline;
    }
}
