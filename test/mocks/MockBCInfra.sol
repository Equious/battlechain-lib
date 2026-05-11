// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AgreementDetails } from "src/types/AgreementTypes.sol";

/// @dev Mock BattleChainDeployer that deploys contracts via CREATE and tracks them.
contract MockBCDeployer {
    event Deployed(address indexed deployer, address indexed deployed);

    function deployCreate(bytes memory initCode) external payable returns (address deployed) {
        assembly {
            deployed := create(callvalue(), add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), "CREATE failed");
        emit Deployed(msg.sender, deployed);
    }

    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address deployed) {
        assembly {
            deployed := create2(callvalue(), add(initCode, 0x20), mload(initCode), salt)
        }
        require(deployed != address(0), "CREATE2 failed");
        emit Deployed(msg.sender, deployed);
    }

    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address deployed) {
        // Simplified: just use CREATE2 for mock purposes
        assembly {
            deployed := create2(callvalue(), add(initCode, 0x20), mload(initCode), salt)
        }
        require(deployed != address(0), "CREATE3 failed");
        emit Deployed(msg.sender, deployed);
    }
}

/// @dev Mock AgreementFactory that deploys a MockAgreement.
contract MockAgreementFactory {
    address public lastAgreement;

    function create(AgreementDetails memory, address owner, bytes32) external returns (address) {
        MockAgreement agreement = new MockAgreement(owner);
        lastAgreement = address(agreement);
        return address(agreement);
    }
}

/// @dev Mock Agreement that tracks commitment window and owner.
contract MockAgreement {
    address public owner;
    uint256 public cantChangeUntil;

    constructor(address owner_) {
        owner = owner_;
    }

    function extendCommitmentWindow(uint256 newCantChangeUntil) external {
        cantChangeUntil = newCantChangeUntil;
    }
}

/// @dev Mock BattleChainSafeHarborRegistry that tracks adoptions.
contract MockBCRegistry {
    mapping(address => address) public agreements;

    function adoptSafeHarbor(address agreementAddress) external {
        agreements[msg.sender] = agreementAddress;
    }

    function getAgreement(address adopter) external view returns (address) {
        return agreements[adopter];
    }
}

/// @dev Mock AttackRegistry that tracks attack requests.
contract MockAttackRegistry {
    mapping(address => bool) public attackRequested;
    mapping(address => bool) public inProduction;

    function requestUnderAttack(address agreementAddress) external {
        attackRequested[agreementAddress] = true;
    }

    function goToProduction(address agreementAddress) external {
        inProduction[agreementAddress] = true;
    }
}

/// @dev Trivial contract for deploy tests.
contract MockToken {
    string public name = "Mock";
}

/// @dev Minimal ERC20 token used by confidence pool tests. Tracks approvals and balances.
contract MockERC20 {
    string public name = "Mock ERC20";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @dev Mock ConfidencePool that tracks user-facing entrypoints. Not state-accurate beyond
/// what BCConfidencePool tests need.
contract MockConfidencePool {
    address public stakeToken;
    address public agreement;
    address public recoveryAddress;
    address public outcomeModerator;
    uint256 public expiry;
    bool public expiryLocked;
    bool public paused_;

    uint256 public lastStakeAmount;
    uint256 public lastBonusAmount;
    uint256 public lastRequestedWithdraw;
    uint256 public withdrawCalls;
    uint256 public cancelCalls;
    uint256 public claimSurvivedCalls;
    uint256 public claimExpiredCalls;
    uint256 public claimCorruptedCalls;
    uint256 public claimAttackerBountyCalls;
    uint256 public claimPendingWithdrawCalls;

    uint8 public lastFlaggedOutcome; // matches PoolStates.Outcome ordering
    bool public lastFlaggedGoodFaith;
    address public lastFlaggedAttacker;
    uint16 public lastFlaggedBountyBps;

    constructor(
        address agreement_,
        address stakeToken_,
        address outcomeModerator_,
        uint256 expiry_,
        address recoveryAddress_
    ) {
        agreement = agreement_;
        stakeToken = stakeToken_;
        outcomeModerator = outcomeModerator_;
        expiry = expiry_;
        recoveryAddress = recoveryAddress_;
    }

    function stake(uint256 amount) external {
        MockERC20(stakeToken).transferFrom(msg.sender, address(this), amount);
        lastStakeAmount = amount;
    }

    function contributeBonus(uint256 amount) external {
        MockERC20(stakeToken).transferFrom(msg.sender, address(this), amount);
        lastBonusAmount = amount;
    }

    function requestWithdraw(uint256 amount) external {
        lastRequestedWithdraw = amount;
    }

    function cancelWithdrawRequest() external {
        cancelCalls++;
    }

    function withdraw() external {
        withdrawCalls++;
    }

    function flagOutcome(uint8 outcome, bool goodFaith, address attacker, uint16 attackerBountyBps) external {
        lastFlaggedOutcome = outcome;
        lastFlaggedGoodFaith = goodFaith;
        lastFlaggedAttacker = attacker;
        lastFlaggedBountyBps = attackerBountyBps;
    }

    function claimSurvived() external {
        claimSurvivedCalls++;
    }

    function claimExpired() external {
        claimExpiredCalls++;
    }

    function claimCorrupted() external {
        claimCorruptedCalls++;
    }

    function claimAttackerBounty() external {
        claimAttackerBountyCalls++;
    }

    function claimPendingWithdraw() external {
        claimPendingWithdrawCalls++;
    }

    function setRecoveryAddress(address newRecoveryAddress) external {
        recoveryAddress = newRecoveryAddress;
    }

    function setExpiry(uint256 newExpiry) external {
        require(!expiryLocked, "ExpiryLocked");
        expiry = newExpiry;
    }

    function pause() external {
        paused_ = true;
    }

    function unpause() external {
        paused_ = false;
    }

    function lockExpiry() external {
        expiryLocked = true;
    }
}

/// @dev Mock ConfidencePoolFactory. Deploys a MockConfidencePool per agreement and tracks the mapping.
contract MockConfidencePoolFactory {
    mapping(address => address) public pools;
    address public defaultOutcomeModerator;
    uint256 public defaultMinStake;

    event PoolCreated(address indexed agreement, address indexed pool);

    constructor(address defaultModerator) {
        defaultOutcomeModerator = defaultModerator;
    }

    function createPool(
        address agreement,
        address stakeToken,
        uint256 expiry,
        address outcomeModeratorOverride,
        address recoveryAddress
    )
        external
        returns (address pool)
    {
        require(pools[agreement] == address(0), "PoolAlreadyExists");
        address moderator = outcomeModeratorOverride == address(0) ? defaultOutcomeModerator : outcomeModeratorOverride;
        pool = address(new MockConfidencePool(agreement, stakeToken, moderator, expiry, recoveryAddress));
        pools[agreement] = pool;
        emit PoolCreated(agreement, pool);
    }
}
