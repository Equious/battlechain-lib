// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(push-zero-opcode,unspecific-solidity-pragma)
pragma solidity ^0.8.24;

import { PoolStates } from "../types/PoolStates.sol";

/// @notice Interface for a ConfidencePool clone. Vendored from bc-confidence-pools.
interface IConfidencePool {
    event Staked(address indexed staker, uint256 amount);
    event BonusContributed(address indexed contributor, uint256 amount);
    event WithdrawRequested(address indexed staker, uint256 amount, uint256 requestedAt);
    event WithdrawCancelled(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event OutcomeFlagged(
        address indexed moderator,
        PoolStates.Outcome outcome,
        bool goodFaith,
        address attacker,
        uint16 attackerBountyBps
    );
    event ClaimSurvived(address indexed staker, uint256 amount);
    event ClaimCorrupted(address indexed caller, address indexed recoveryAddress, uint256 amount);
    event AttackerBountyClaimed(address indexed attacker, uint256 amount);
    event ClaimExpired(address indexed staker, uint256 amount);
    event ClaimPendingWithdraw(address indexed staker, uint256 amount);
    event RecoveryAddressUpdated(address indexed oldAddr, address indexed newAddr);
    event ExpiryUpdated(uint256 oldExpiry, uint256 newExpiry);

    error PoolPaused();
    error PoolNotPaused();
    error InvalidAmount();
    error BelowMinStake();
    error StakingClosed();
    error OutcomeAlreadySet();
    error OutcomeNotSet();
    error InvalidOutcome();
    error NotModerator();
    error NotAttacker();
    error BountyAlreadyClaimed();
    error InvalidGoodFaithParams();
    error WithdrawAlreadyPending();
    error NoWithdrawPending();
    error WithdrawDelayNotMet();
    error WithdrawsDisabled();
    error ExpiryLocked();
    error ExpiryTooSoon();
    error InvalidRecoveryAddress();
    error PoolNotExpired();
    error InvalidAgreement();
    error ZeroAddress();
    error MustUseFullClaim();

    function initialize(
        address agreement,
        address stakeToken,
        address safeHarborRegistry,
        address outcomeModerator,
        uint256 expiry,
        uint256 minStake,
        address recoveryAddress
    )
        external;

    function stake(uint256 amount) external;
    function contributeBonus(uint256 amount) external;
    function requestWithdraw(uint256 amount) external;
    function cancelWithdrawRequest() external;
    function withdraw() external;

    function flagOutcome(
        PoolStates.Outcome outcome,
        bool goodFaith,
        address attacker,
        uint16 attackerBountyBps
    )
        external;

    function claimSurvived() external;
    function claimCorrupted() external;
    function claimAttackerBounty() external;
    function claimExpired() external;
    function claimPendingWithdraw() external;

    function setRecoveryAddress(address newRecoveryAddress) external;
    function setExpiry(uint256 newExpiry) external;
    function pause() external;
    function unpause() external;

    function agreement() external view returns (address);
    function stakeToken() external view returns (address);
    function outcomeModerator() external view returns (address);
    function expiry() external view returns (uint256);
    function minStake() external view returns (uint256);
    function recoveryAddress() external view returns (address);
    function totalStaked() external view returns (uint256);
    function totalBonus() external view returns (uint256);
    function totalPendingWithdraw() external view returns (uint256);
    function stakes(address staker) external view returns (uint256);
    function outcome() external view returns (PoolStates.Outcome);
    function expiryLocked() external view returns (bool);
}
