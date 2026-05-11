// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(push-zero-opcode,unspecific-solidity-pragma)
pragma solidity ^0.8.24;

import { BCBase } from "./BCBase.sol";
import { IConfidencePoolFactory } from "./interfaces/IConfidencePoolFactory.sol";
import { IConfidencePool } from "./interfaces/IConfidencePool.sol";
import { PoolStates } from "./types/PoolStates.sol";

/// @notice Minimal ERC20 surface used for approve flows.
interface IERC20Approve {
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @notice Builder and interaction helpers for BattleChain Confidence Pools.
/// @dev Mirrors BCSafeHarbor's style: builders + script-friendly wrappers around the
///      factory and per-pool entrypoints. Sponsor, staker, and DAO/moderator flows are
///      all covered so scripts can stay terse.
abstract contract BCConfidencePool is BCBase {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Minimum expiry lead enforced by the factory and pool. Pool creation
    /// helpers default to this when no explicit expiry is supplied.
    uint256 internal constant DEFAULT_POOL_EXPIRY_LEAD = 30 days;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BCConfidencePool__PoolAlreadyExists(address agreement, address existingPool);
    error BCConfidencePool__PoolNotFound(address agreement);

    // -------------------------------------------------------------------------
    // Sponsor: pool creation
    // -------------------------------------------------------------------------

    /// @notice Creates a confidence pool around an agreement with the factory default moderator,
    /// recovery address sourced from the caller, and a 30-day expiry from `block.timestamp`.
    function createPool(address agreement, address stakeToken, address recoveryAddr) internal returns (address pool) {
        return createPoolWithExpiry(
            agreement, stakeToken, recoveryAddr, block.timestamp + DEFAULT_POOL_EXPIRY_LEAD, address(0)
        );
    }

    /// @notice Creates a confidence pool with an explicit expiry and the factory default moderator.
    function createPoolWithExpiry(
        address agreement,
        address stakeToken,
        address recoveryAddr,
        uint256 expiry
    )
        internal
        returns (address pool)
    {
        return createPoolWithExpiry(agreement, stakeToken, recoveryAddr, expiry, address(0));
    }

    /// @notice Creates a confidence pool with an explicit expiry and an explicit moderator override.
    /// Pass `address(0)` for `outcomeModeratorOverride` to use the factory default moderator.
    function createPoolWithExpiry(
        address agreement,
        address stakeToken,
        address recoveryAddr,
        uint256 expiry,
        address outcomeModeratorOverride
    )
        internal
        returns (address pool)
    {
        address existing = IConfidencePoolFactory(_bcConfidencePoolFactory()).pools(agreement);
        if (existing != address(0)) revert BCConfidencePool__PoolAlreadyExists(agreement, existing);

        pool = IConfidencePoolFactory(_bcConfidencePoolFactory())
            .createPool(agreement, stakeToken, expiry, outcomeModeratorOverride, recoveryAddr);
    }

    /// @notice Reads the pool address for an agreement; reverts if no pool exists.
    function getPool(address agreement) internal view returns (address pool) {
        pool = IConfidencePoolFactory(_bcConfidencePoolFactory()).pools(agreement);
        if (pool == address(0)) revert BCConfidencePool__PoolNotFound(agreement);
    }

    /// @notice Same as `getPool` but returns `address(0)` instead of reverting.
    function tryGetPool(address agreement) internal view returns (address pool) {
        return IConfidencePoolFactory(_bcConfidencePoolFactory()).pools(agreement);
    }

    // -------------------------------------------------------------------------
    // Sponsor: pool administration
    // -------------------------------------------------------------------------

    /// @notice Updates the pool's recovery address. Sponsor-only.
    function setPoolRecoveryAddress(address pool, address newRecoveryAddress) internal {
        IConfidencePool(pool).setRecoveryAddress(newRecoveryAddress);
    }

    /// @notice Updates the pool's expiry. Sponsor-only; reverts after the first stake.
    function setPoolExpiry(address pool, uint256 newExpiry) internal {
        IConfidencePool(pool).setExpiry(newExpiry);
    }

    function pausePool(address pool) internal {
        IConfidencePool(pool).pause();
    }

    function unpausePool(address pool) internal {
        IConfidencePool(pool).unpause();
    }

    // -------------------------------------------------------------------------
    // Stakers and bonus contributors
    // -------------------------------------------------------------------------

    /// @notice Approves the pool to pull `amount` of its stake token and stakes it in one call.
    function approveAndStake(address pool, uint256 amount) internal {
        address token = IConfidencePool(pool).stakeToken();
        IERC20Approve(token).approve(pool, amount);
        IConfidencePool(pool).stake(amount);
    }

    /// @notice Approves the pool to pull `amount` of its stake token and contributes it as bonus.
    function approveAndContributeBonus(address pool, uint256 amount) internal {
        address token = IConfidencePool(pool).stakeToken();
        IERC20Approve(token).approve(pool, amount);
        IConfidencePool(pool).contributeBonus(amount);
    }

    function requestPoolWithdraw(address pool, uint256 amount) internal {
        IConfidencePool(pool).requestWithdraw(amount);
    }

    function cancelPoolWithdraw(address pool) internal {
        IConfidencePool(pool).cancelWithdrawRequest();
    }

    function withdrawFromPool(address pool) internal {
        IConfidencePool(pool).withdraw();
    }

    // -------------------------------------------------------------------------
    // Claims
    // -------------------------------------------------------------------------

    function claimSurvived(address pool) internal {
        IConfidencePool(pool).claimSurvived();
    }

    function claimExpired(address pool) internal {
        IConfidencePool(pool).claimExpired();
    }

    function claimCorrupted(address pool) internal {
        IConfidencePool(pool).claimCorrupted();
    }

    function claimAttackerBounty(address pool) internal {
        IConfidencePool(pool).claimAttackerBounty();
    }

    function claimPendingWithdraw(address pool) internal {
        IConfidencePool(pool).claimPendingWithdraw();
    }

    // -------------------------------------------------------------------------
    // Outcome moderator (DAO)
    // -------------------------------------------------------------------------

    /// @notice Flags the pool as SURVIVED. Requires the agreement to be in PRODUCTION upstream.
    function flagPoolSurvived(address pool) internal {
        IConfidencePool(pool).flagOutcome(PoolStates.Outcome.SURVIVED, false, address(0), 0);
    }

    /// @notice Flags the pool as CORRUPTED bad-faith. All stake + bonus sweeps to `recoveryAddress`.
    function flagPoolCorruptedBadFaith(address pool) internal {
        IConfidencePool(pool).flagOutcome(PoolStates.Outcome.CORRUPTED, false, address(0), 0);
    }

    /// @notice Flags the pool as CORRUPTED good-faith. `attacker` may claim `attackerBountyBps`
    /// of the snapshot before the remainder sweeps to `recoveryAddress`.
    function flagPoolCorruptedGoodFaith(address pool, address attacker, uint16 attackerBountyBps) internal {
        IConfidencePool(pool).flagOutcome(PoolStates.Outcome.CORRUPTED, true, attacker, attackerBountyBps);
    }
}
