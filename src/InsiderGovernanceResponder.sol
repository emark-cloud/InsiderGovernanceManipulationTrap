// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title InsiderGovernanceResponder
 * @notice
 * Handles responses to insider governance manipulation alerts.
 * All side effects live here (never in the Trap).
 *
 * Compatible with Drosera:
 * - handle(bytes) is called by Drosera executor
 * - payload format must match Trap encoding
 */
contract InsiderGovernanceResponder {
    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    address public owner;
    address public caller; // Drosera executor / relay

    uint8 public severityThreshold = 7;

    /* -------------------------------------------------------------------------- */
    /*                                    EVENTS                                  */
    /* -------------------------------------------------------------------------- */

    event GovernanceIncidentHandled(
        uint8  severity,
        uint64 proposerAgeDays,
        bool   fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avgProposalFrequency30d,
        uint16 voteSpikePercent,
        uint16 correlationScore,
        bytes32 reasonHash
    );

    event CallerUpdated(address newCaller);
    event ThresholdUpdated(uint8 newThreshold);
    event OwnershipTransferred(address newOwner);

    /* -------------------------------------------------------------------------- */
    /*                                   MODIFIERS                                */
    /* -------------------------------------------------------------------------- */

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyCaller() {
        require(msg.sender == caller, "UNAUTHORIZED_CALLER");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor() {
        owner = msg.sender;
    }

    /* -------------------------------------------------------------------------- */
    /*                              ADMIN FUNCTIONS                               */
    /* -------------------------------------------------------------------------- */

    function setCaller(address newCaller) external onlyOwner {
        require(newCaller != address(0), "ZERO_CALLER");
        caller = newCaller;
        emit CallerUpdated(newCaller);
    }

    function setSeverityThreshold(uint8 newThreshold)
        external
        onlyOwner
    {
        require(newThreshold > 0 && newThreshold <= 10, "INVALID_THRESHOLD");
        severityThreshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   HANDLE                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Called by Drosera when Trap triggers.
     * @param payload ABI encoded:
     * (
     *   uint8 severity,
     *   uint64 proposerAgeDays,
     *   bool fundedFromCEX,
     *   uint32 proposalFrequency30d,
     *   uint32 avgProposalFrequency30d,
     *   uint16 voteSpikePercent,
     *   uint16 correlationScore
     * )
     */
    function handle(bytes calldata payload)
        external
        onlyCaller
    {
        if (payload.length == 0) return;

        (
            uint8 severity,
            uint64 proposerAgeDays,
            bool fundedFromCEX,
            uint32 proposalFrequency30d,
            uint32 avgProposalFrequency30d,
            uint16 voteSpikePercent,
            uint16 correlationScore
        ) = abi.decode(
            payload,
            (uint8, uint64, bool, uint32, uint32, uint16, uint16)
        );

        // Ignore low-severity alerts
        if (severity < severityThreshold) {
            return;
        }

        bytes32 reasonHash = keccak256(
            abi.encodePacked(
                "INSIDER_GOVERNANCE_RISK",
                severity,
                proposerAgeDays,
                fundedFromCEX,
                proposalFrequency30d,
                voteSpikePercent,
                correlationScore
            )
        );

        emit GovernanceIncidentHandled(
            severity,
            proposerAgeDays,
            fundedFromCEX,
            proposalFrequency30d,
            avgProposalFrequency30d,
            voteSpikePercent,
            correlationScore,
            reasonHash
        );

        /* ---------------------------------------------------------------------- */
        /*                    OPTIONAL PROTOCOL-SPECIFIC ACTIONS                  */
        /* ---------------------------------------------------------------------- */

        // Example integrations:
        // pauseGovernance();
        // enforceTimelockDelay();
        // revokeProposerRole();
        // triggerGuardian();
    }
}
