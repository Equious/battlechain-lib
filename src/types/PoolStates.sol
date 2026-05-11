// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(push-zero-opcode,unspecific-solidity-pragma)
pragma solidity ^0.8.24;

/// @notice Shared confidence pool outcome states. Vendored from bc-confidence-pools.
library PoolStates {
    enum Outcome {
        UNRESOLVED,
        SURVIVED,
        CORRUPTED,
        EXPIRED
    }

    function isTerminal(Outcome outcome) internal pure returns (bool) {
        return outcome != Outcome.UNRESOLVED;
    }
}
