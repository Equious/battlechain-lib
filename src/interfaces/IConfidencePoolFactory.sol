// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(push-zero-opcode,unspecific-solidity-pragma)
pragma solidity ^0.8.24;

/// @notice Interface for the ConfidencePoolFactory. Vendored from bc-confidence-pools.
interface IConfidencePoolFactory {
    event PoolCreated(
        address indexed agreement, address indexed pool, address stakeToken, uint256 expiry, address recoveryAddress
    );
    event SafeHarborRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event PoolImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
    event DefaultOutcomeModeratorUpdated(address indexed oldModerator, address indexed newModerator);
    event DefaultMinStakeUpdated(uint256 oldMinStake, uint256 newMinStake);

    error PoolAlreadyExists();
    error InvalidAgreement();
    error ExpiryTooSoon();
    error ZeroAddress();

    function initialize(
        address safeHarborRegistry,
        address poolImplementation,
        address defaultOutcomeModerator,
        uint256 defaultMinStake
    )
        external;

    function createPool(
        address agreement,
        address stakeToken,
        uint256 expiry,
        address outcomeModeratorOverride,
        address recoveryAddress
    )
        external
        returns (address pool);

    function setSafeHarborRegistry(address newSafeHarborRegistry) external;
    function setPoolImplementation(address newPoolImplementation) external;
    function setDefaultOutcomeModerator(address newDefaultOutcomeModerator) external;
    function setDefaultMinStake(uint256 newDefaultMinStake) external;

    function pause() external;
    function unpause() external;

    function pools(address agreement) external view returns (address);
    function poolImplementation() external view returns (address);
    function defaultOutcomeModerator() external view returns (address);
    function defaultMinStake() external view returns (uint256);
}
