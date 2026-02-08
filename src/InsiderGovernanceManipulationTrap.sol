// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITrap.sol";

/**
 * @notice
 * Off-chain operators compute governance risk metrics and store them
 * in a feeder contract. The trap only evaluates encoded summaries.
 */
contract InsiderGovernanceManipulationTrap is ITrap {
    /* -------------------------------------------------------------------------- */
    /*                                   Types                                    */
    /* -------------------------------------------------------------------------- */

    struct GovSummary {
        uint64  proposerAgeDays;
        bool    fundedFromCEX;
        uint32  proposalFrequency30d;
        uint32  avgProposalFrequency30d;
        uint16  voteSpikePercent;     // % of votes in single block
        uint16  correlationScore;     // proposer/voter overlap score
    }

    /* -------------------------------------------------------------------------- */
    /*                                  COLLECT                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice
     * Drosera operators must supply summaries externally.
     * collect() simply returns the latest encoded summary.
     *
     * If no data is available, return empty bytes.
     */
    function collect()
        external
        view
        override
        returns (bytes memory)
    {
        // This trap expects the operator to inject the summary.
        // Returning empty bytes is planner-safe.
        return bytes("");
    }

    /* -------------------------------------------------------------------------- */
    /*                               SHOULD RESPOND                               */
    /* -------------------------------------------------------------------------- */

    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length == 0 || data[0].length == 0) {
            return (false, "");
        }

        GovSummary memory g = abi.decode(data[0], (GovSummary));

        uint8 severity = 0;

        // Strong insider pattern
        if (
            g.proposerAgeDays < 7 &&
            g.fundedFromCEX &&
            g.voteSpikePercent >= 70 &&
            g.correlationScore >= 70
        ) {
            severity = 10;
        }
        // Medium confidence manipulation
        else if (
            g.voteSpikePercent >= 60 &&
            g.correlationScore >= 60
        ) {
            severity = 7;
        }
        // Early anomaly
        else if (
            g.proposalFrequency30d >
            g.avgProposalFrequency30d * 2
        ) {
            severity = 5;
        }

        if (severity == 0) {
            return (false, "");
        }

        bytes memory payload = abi.encode(
            severity,
            g.proposerAgeDays,
            g.fundedFromCEX,
            g.proposalFrequency30d,
            g.avgProposalFrequency30d,
            g.voteSpikePercent,
            g.correlationScore
        );

        return (true, payload);
    }
}
