// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice
 * Handles responses to insider governance manipulation alerts.
 * All side effects and logging live here (NOT in the trap).
 */
contract InsiderGovernanceResponder {
    address public owner;
    address public caller; // Drosera relay / executor

    uint8 public severityThreshold = 7;

    event GovernanceIncidentHandled(
        uint8  severity,
        uint64 proposerAgeDays,
        bool   fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avg30d,
        uint16 voteSpikePercent,
        uint16 correlationScore,
        bytes32 reasonHash
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyCaller() {
        require(msg.sender == caller, "UNAUTHORIZED");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /* -------------------------------------------------------------------------- */
    /*                              ADMIN CONTROLS                                */
    /* -------------------------------------------------------------------------- */

    function setCaller(address c) external onlyOwner {
        require(c != address(0), "ZERO_CALLER");
        caller = c;
    }

    function setSeverityThreshold(uint8 s) external onlyOwner {
        require(s > 0 && s <= 10, "INVALID_SEVERITY");
        severityThreshold = s;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   HANDLE                                   */
    /* -------------------------------------------------------------------------- */

    function handle(bytes calldata payload)
        external
        onlyCaller
    {
        (
            uint8 severity,
            uint64 proposerAgeDays,
            bool fundedFromCEX,
            uint32 proposalFrequency30d,
            uint32 avg30d,
            uint16 voteSpikePercent,
            uint16 correlationScore
        ) = abi.decode(
            payload,
            (uint8, uint64, bool, uint32, uint32, uint16, uint16)
        );

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
            avg30d,
            voteSpikePercent,
            correlationScore,
            reasonHash
        );

        // Optional extensions:
        // pauseGovernance();
        // enforceDelay();
        // revokeAdmin();
    }
}
