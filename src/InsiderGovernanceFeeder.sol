// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract InsiderGovernanceFeeder {
    /* -------------------------------------------------------------------------- */
    /*                                   TYPES                                    */
    /* -------------------------------------------------------------------------- */

    struct GovSummary {
        uint64  proposerAgeDays;
        bool    fundedFromCEX;
        uint32  proposalFrequency30d;
        uint32  avgProposalFrequency30d;
        uint16  voteSpikePercent;
        uint16  correlationScore;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    address public owner;
    GovSummary private latest;

    uint256 public lastUpdatedBlock;
    uint256 public lastUpdatedTimestamp;

    /* -------------------------------------------------------------------------- */
    /*                                    EVENTS                                  */
    /* -------------------------------------------------------------------------- */

    event GovSummaryUpdated(
        uint64 proposerAgeDays,
        bool fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avgProposalFrequency30d,
        uint16 voteSpikePercent,
        uint16 correlationScore,
        uint256 blockNumber,
        uint256 timestamp
    );

    event OwnershipTransferred(address newOwner);

    /* -------------------------------------------------------------------------- */
    /*                                   MODIFIERS                                */
    /* -------------------------------------------------------------------------- */

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(address initialOwner) {
        require(initialOwner != address(0), "ZERO_OWNER");
        owner = initialOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                             OWNERSHIP CONTROL                              */
    /* -------------------------------------------------------------------------- */

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }

    /* -------------------------------------------------------------------------- */
    /*                              UPDATE SUMMARY                                */
    /* -------------------------------------------------------------------------- */

    function updateSummary(
        uint64 proposerAgeDays,
        bool fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avgProposalFrequency30d,
        uint16 voteSpikePercent,
        uint16 correlationScore
    ) external onlyOwner {
        latest = GovSummary({
            proposerAgeDays: proposerAgeDays,
            fundedFromCEX: fundedFromCEX,
            proposalFrequency30d: proposalFrequency30d,
            avgProposalFrequency30d: avgProposalFrequency30d,
            voteSpikePercent: voteSpikePercent,
            correlationScore: correlationScore
        });

        lastUpdatedBlock = block.number;
        lastUpdatedTimestamp = block.timestamp;

        emit GovSummaryUpdated(
            proposerAgeDays,
            fundedFromCEX,
            proposalFrequency30d,
            avgProposalFrequency30d,
            voteSpikePercent,
            correlationScore,
            block.number,
            block.timestamp
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                   VIEW                                     */
    /* -------------------------------------------------------------------------- */

    function getLatest()
        external
        view
        returns (GovSummary memory)
    {
        return latest;
    }

    function isFresh(uint256 maxAgeSeconds)
        external
        view
        returns (bool)
    {
        if (lastUpdatedTimestamp == 0) return false;
        return (block.timestamp - lastUpdatedTimestamp) <= maxAgeSeconds;
    }
}
