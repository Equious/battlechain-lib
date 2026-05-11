// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BCConfidencePool } from "src/BCConfidencePool.sol";
import { PoolStates } from "src/types/PoolStates.sol";
import { MockConfidencePoolFactory, MockConfidencePool, MockERC20 } from "test/mocks/MockBCInfra.sol";

contract BCConfidencePoolHarness is BCConfidencePool {
    function configure(address poolFactory) external {
        _setConfidencePoolFactory(poolFactory);
    }

    function exposedCreatePool(address agreement, address stakeToken, address recoveryAddr) external returns (address) {
        return createPool(agreement, stakeToken, recoveryAddr);
    }

    function exposedCreatePoolWithExpiry(
        address agreement,
        address stakeToken,
        address recoveryAddr,
        uint256 expiry_
    )
        external
        returns (address)
    {
        return createPoolWithExpiry(agreement, stakeToken, recoveryAddr, expiry_);
    }

    function exposedCreatePoolWithModerator(
        address agreement,
        address stakeToken,
        address recoveryAddr,
        uint256 expiry_,
        address moderatorOverride
    )
        external
        returns (address)
    {
        return createPoolWithExpiry(agreement, stakeToken, recoveryAddr, expiry_, moderatorOverride);
    }

    function exposedGetPool(address agreement) external view returns (address) {
        return getPool(agreement);
    }

    function exposedTryGetPool(address agreement) external view returns (address) {
        return tryGetPool(agreement);
    }

    function exposedApproveAndStake(address pool, uint256 amount) external {
        approveAndStake(pool, amount);
    }

    function exposedApproveAndContributeBonus(address pool, uint256 amount) external {
        approveAndContributeBonus(pool, amount);
    }

    function exposedRequestWithdraw(address pool, uint256 amount) external {
        requestPoolWithdraw(pool, amount);
    }

    function exposedCancelWithdraw(address pool) external {
        cancelPoolWithdraw(pool);
    }

    function exposedWithdraw(address pool) external {
        withdrawFromPool(pool);
    }

    function exposedClaimSurvived(address pool) external {
        claimSurvived(pool);
    }

    function exposedClaimExpired(address pool) external {
        claimExpired(pool);
    }

    function exposedClaimCorrupted(address pool) external {
        claimCorrupted(pool);
    }

    function exposedClaimAttackerBounty(address pool) external {
        claimAttackerBounty(pool);
    }

    function exposedClaimPendingWithdraw(address pool) external {
        claimPendingWithdraw(pool);
    }

    function exposedFlagSurvived(address pool) external {
        flagPoolSurvived(pool);
    }

    function exposedFlagCorruptedBadFaith(address pool) external {
        flagPoolCorruptedBadFaith(pool);
    }

    function exposedFlagCorruptedGoodFaith(address pool, address attacker, uint16 bps) external {
        flagPoolCorruptedGoodFaith(pool, attacker, bps);
    }

    function exposedSetPoolRecoveryAddress(address pool, address newAddr) external {
        setPoolRecoveryAddress(pool, newAddr);
    }

    function exposedSetPoolExpiry(address pool, uint256 newExpiry) external {
        setPoolExpiry(pool, newExpiry);
    }

    function exposedPausePool(address pool) external {
        pausePool(pool);
    }

    function exposedUnpausePool(address pool) external {
        unpausePool(pool);
    }
}

contract BCConfidencePoolTest is Test {
    BCConfidencePoolHarness harness;
    MockConfidencePoolFactory factory;
    MockERC20 token;

    address agreement = address(0xAAA);
    address recoveryAddr = address(0xBBB);
    address moderator = address(0xCCC);
    address attacker = address(0xDDD);

    function setUp() public {
        vm.chainId(627);

        harness = new BCConfidencePoolHarness();
        factory = new MockConfidencePoolFactory(moderator);
        token = new MockERC20();

        harness.configure(address(factory));
    }

    // -------------------------------------------------------------------------
    // Pool creation
    // -------------------------------------------------------------------------

    function test_createPool_usesDefaultExpiryAndModerator() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        assertEq(factory.pools(agreement), pool);
        assertEq(MockConfidencePool(pool).expiry(), block.timestamp + 30 days);
        assertEq(MockConfidencePool(pool).outcomeModerator(), moderator);
        assertEq(MockConfidencePool(pool).recoveryAddress(), recoveryAddr);
    }

    function test_createPoolWithExpiry_usesGivenExpiry() public {
        uint256 customExpiry = block.timestamp + 90 days;
        address pool = harness.exposedCreatePoolWithExpiry(agreement, address(token), recoveryAddr, customExpiry);
        assertEq(MockConfidencePool(pool).expiry(), customExpiry);
    }

    function test_createPoolWithModerator_overridesDefault() public {
        address customModerator = address(0xEEEE);
        address pool = harness.exposedCreatePoolWithModerator(
            agreement, address(token), recoveryAddr, block.timestamp + 30 days, customModerator
        );
        assertEq(MockConfidencePool(pool).outcomeModerator(), customModerator);
    }

    function test_createPool_revertsIfPoolAlreadyExists() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        vm.expectRevert(
            abi.encodeWithSelector(BCConfidencePool.BCConfidencePool__PoolAlreadyExists.selector, agreement, pool)
        );
        harness.exposedCreatePool(agreement, address(token), recoveryAddr);
    }

    // -------------------------------------------------------------------------
    // Lookups
    // -------------------------------------------------------------------------

    function test_getPool_revertsWhenMissing() public {
        vm.expectRevert(abi.encodeWithSelector(BCConfidencePool.BCConfidencePool__PoolNotFound.selector, agreement));
        harness.exposedGetPool(agreement);
    }

    function test_getPool_returnsCreatedPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);
        assertEq(harness.exposedGetPool(agreement), pool);
    }

    function test_tryGetPool_returnsZeroWhenMissing() public view {
        assertEq(harness.exposedTryGetPool(agreement), address(0));
    }

    // -------------------------------------------------------------------------
    // Staker flows
    // -------------------------------------------------------------------------

    function test_approveAndStake_pullsTokensAndCallsStake() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);
        token.mint(address(harness), 100);

        harness.exposedApproveAndStake(pool, 75);

        assertEq(MockConfidencePool(pool).lastStakeAmount(), 75);
        assertEq(token.balanceOf(pool), 75);
        assertEq(token.balanceOf(address(harness)), 25);
    }

    function test_approveAndContributeBonus_pullsTokensAndCallsBonus() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);
        token.mint(address(harness), 200);

        harness.exposedApproveAndContributeBonus(pool, 200);

        assertEq(MockConfidencePool(pool).lastBonusAmount(), 200);
        assertEq(token.balanceOf(pool), 200);
    }

    function test_withdrawHelpers_delegateToPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedRequestWithdraw(pool, 50);
        assertEq(MockConfidencePool(pool).lastRequestedWithdraw(), 50);

        harness.exposedCancelWithdraw(pool);
        assertEq(MockConfidencePool(pool).cancelCalls(), 1);

        harness.exposedWithdraw(pool);
        assertEq(MockConfidencePool(pool).withdrawCalls(), 1);
    }

    // -------------------------------------------------------------------------
    // Claim helpers
    // -------------------------------------------------------------------------

    function test_claimHelpers_delegateToPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedClaimSurvived(pool);
        harness.exposedClaimExpired(pool);
        harness.exposedClaimCorrupted(pool);
        harness.exposedClaimAttackerBounty(pool);
        harness.exposedClaimPendingWithdraw(pool);

        assertEq(MockConfidencePool(pool).claimSurvivedCalls(), 1);
        assertEq(MockConfidencePool(pool).claimExpiredCalls(), 1);
        assertEq(MockConfidencePool(pool).claimCorruptedCalls(), 1);
        assertEq(MockConfidencePool(pool).claimAttackerBountyCalls(), 1);
        assertEq(MockConfidencePool(pool).claimPendingWithdrawCalls(), 1);
    }

    // -------------------------------------------------------------------------
    // Moderator helpers
    // -------------------------------------------------------------------------

    function test_flagSurvived_writesSurvivedOutcome() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedFlagSurvived(pool);

        assertEq(MockConfidencePool(pool).lastFlaggedOutcome(), uint8(PoolStates.Outcome.SURVIVED));
        assertEq(MockConfidencePool(pool).lastFlaggedGoodFaith(), false);
        assertEq(MockConfidencePool(pool).lastFlaggedAttacker(), address(0));
        assertEq(MockConfidencePool(pool).lastFlaggedBountyBps(), 0);
    }

    function test_flagCorruptedBadFaith_writesCorruptedWithBlankParams() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedFlagCorruptedBadFaith(pool);

        assertEq(MockConfidencePool(pool).lastFlaggedOutcome(), uint8(PoolStates.Outcome.CORRUPTED));
        assertEq(MockConfidencePool(pool).lastFlaggedGoodFaith(), false);
        assertEq(MockConfidencePool(pool).lastFlaggedAttacker(), address(0));
        assertEq(MockConfidencePool(pool).lastFlaggedBountyBps(), 0);
    }

    function test_flagCorruptedGoodFaith_writesAllParams() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedFlagCorruptedGoodFaith(pool, attacker, 1500);

        assertEq(MockConfidencePool(pool).lastFlaggedOutcome(), uint8(PoolStates.Outcome.CORRUPTED));
        assertEq(MockConfidencePool(pool).lastFlaggedGoodFaith(), true);
        assertEq(MockConfidencePool(pool).lastFlaggedAttacker(), attacker);
        assertEq(MockConfidencePool(pool).lastFlaggedBountyBps(), 1500);
    }

    // -------------------------------------------------------------------------
    // Sponsor admin helpers
    // -------------------------------------------------------------------------

    function test_setPoolRecoveryAddress_updatesPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);
        address newAddr = address(0xFFFF);

        harness.exposedSetPoolRecoveryAddress(pool, newAddr);
        assertEq(MockConfidencePool(pool).recoveryAddress(), newAddr);
    }

    function test_setPoolExpiry_updatesPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);
        uint256 newExpiry = block.timestamp + 120 days;

        harness.exposedSetPoolExpiry(pool, newExpiry);
        assertEq(MockConfidencePool(pool).expiry(), newExpiry);
    }

    function test_pauseUnpause_togglesPool() public {
        address pool = harness.exposedCreatePool(agreement, address(token), recoveryAddr);

        harness.exposedPausePool(pool);
        assertTrue(MockConfidencePool(pool).paused_());

        harness.exposedUnpausePool(pool);
        assertFalse(MockConfidencePool(pool).paused_());
    }
}
