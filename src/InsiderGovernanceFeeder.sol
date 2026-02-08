// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice
 * Stores off-chain computed governance risk summaries
 * for InsiderGovernanceManipulationTrap.
 *
 * Heavy analytics happen off-chain.
 * This contract is just a trusted data carrier.
 */
contract InsiderGovernanceFeeder {
    /* -------------------------------------------------------------------------- */
    /*                                   Types                                    */
    /* -------------------------------------------------------------------------- */

    struct GovSummary {
        uint64  proposerAgeDays;
        bool    fundedFromCEX;
        uint32  proposalFrequency30d;
        uint32  avgProposalFrequency30d;
        uint16  voteSpikePercent;   // % of votes in single block
        uint16  correlationScore;   // proposer/voter overlap score
    }

    /* -------------------------------------------------------------------------- */
    /*                                   State                                    */
    /* -------------------------------------------------------------------------- */

    address public owner;
    GovSummary private latest;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event GovSummaryUpdated(
        uint64 proposerAgeDays,
        bool fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avgProposalFrequency30d,
        uint16 voteSpikePercent,
        uint16 correlationScore
    );

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers                                  */
    /* -------------------------------------------------------------------------- */

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Constructor                                 */
    /* -------------------------------------------------------------------------- */

    constructor() {
        // Drosera pattern: owner set after deployment
        owner = address(0);
    }

    function setOwner(address newOwner) external {
        require(owner == address(0), "OWNER_ALREADY_SET");
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Update Summary                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice
     * Called by off-chain operator once per block (or cadence)
     * after computing governance risk metrics.
     */
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

        emit GovSummaryUpdated(
            proposerAgeDays,
            fundedFromCEX,
            proposalFrequency30d,
            avgProposalFrequency30d,
            voteSpikePercent,
            correlationScore
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                   View                                     */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice
     * Read-only access for the trap's collect().
     */
    function getLatest()
        external
        view
        returns (GovSummary memory)
    {
        return latest;
    }
}
