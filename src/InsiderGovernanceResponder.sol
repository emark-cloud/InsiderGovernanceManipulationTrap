// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGuardian {
    function pauseProtocol(bytes32 reasonHash) external;
}

contract InsiderGovernanceResponder {
    /* -------------------------------------------------------------------------- */
    /*                                   Config                                   */
    /* -------------------------------------------------------------------------- */

    address public owner;
    IGuardian public guardian;
    uint8 public severityThreshold = 7; // Only auto-respond to sev >= 7

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(address _guardian) {
        owner = msg.sender;
        guardian = IGuardian(_guardian);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event GovernanceIncidentHandled(
        uint8 severity,
        uint64 proposerAgeDays,
        bool fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avg30d,
        uint16 voteSpikePercent,
        uint16 correlationScore,
        uint256 blockNumber,
        uint64 timestamp,
        bytes32 reasonHash
    );

    /* -------------------------------------------------------------------------- */
    /*                             Admin configuration                            */
    /* -------------------------------------------------------------------------- */

    function setSeverityThreshold(uint8 _sev) external onlyOwner {
        require(_sev <= 10, "INVALID_SEVERITY");
        severityThreshold = _sev;
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = IGuardian(_guardian);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Response                                  */
    /* -------------------------------------------------------------------------- */

   
    function handle(bytes calldata payload) external {
        (
            uint8 severity,
            uint64 proposerAgeDays,
            bool fundedFromCEX,
            uint32 proposalFrequency30d,
            uint32 avg30d,
            uint16 voteSpikePercent,
            uint16 correlationScore,
            uint256 blk,
            uint64 ts
        ) = abi.decode(
            payload,
            (uint8, uint64, bool, uint32, uint32, uint16, uint16, uint256, uint64)
        );

        
        if (severity < severityThreshold) {
            
            emit GovernanceIncidentHandled(
                severity,
                proposerAgeDays,
                fundedFromCEX,
                proposalFrequency30d,
                avg30d,
                voteSpikePercent,
                correlationScore,
                blk,
                ts,
                bytes32(0)
            );
            return;
        }

        
        bytes32 reasonHash = keccak256(
            abi.encodePacked(
                "INSIDER_GOVERNANCE_RISK",
                severity,
                proposerAgeDays,
                fundedFromCEX,
                proposalFrequency30d,
                avg30d,
                voteSpikePercent,
                correlationScore,
                blk,
                ts
            )
        );

        
        if (address(guardian) != address(0)) {
            guardian.pauseProtocol(reasonHash);
        }

        emit GovernanceIncidentHandled(
            severity,
            proposerAgeDays,
            fundedFromCEX,
            proposalFrequency30d,
            avg30d,
            voteSpikePercent,
            correlationScore,
            blk,
            ts,
            reasonHash
        );
    }
}

