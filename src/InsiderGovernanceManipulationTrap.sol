// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITrap.sol";

/**
 * @notice
 * Detects insider-style governance manipulation using
 * off-chain computed forensic metrics supplied via a feeder.
 *
 * Fully Drosera-compliant:
 * - collect() is view and safe
 * - shouldRespond() is pure
 * - no events, no state writes, no block access
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
    /*                                  Feeder                                    */
    /* -------------------------------------------------------------------------- */

    /// @notice Deployed InsiderGovernanceFeeder address
    address public immutable FEEDER;

    interface IGovFeeder {
        function getLatest()
            external
            view
            returns (GovSummary memory);
    }

    constructor(address feeder) {
        require(feeder != address(0), "ZERO_FEEDER");
        FEEDER = feeder;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   COLLECT                                  */
    /* -------------------------------------------------------------------------- */

    function collect()
        external
        view
        override
        returns (bytes memory)
    {
        uint256 size;
        assembly {
            size := extcodesize(FEEDER)
        }
        if (size == 0) return bytes("");

        try IGovFeeder(FEEDER).getLatest()
            returns (GovSummary memory g)
        {
            return abi.encode(g);
        } catch {
            return bytes("");
        }
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

        GovSummary memory g =
            abi.decode(data[0], (GovSummary));

        uint8 severity = 0;

        // High confidence insider manipulation
        if (
            g.proposerAgeDays < 7 &&
            g.fundedFromCEX &&
            g.voteSpikePercent >= 70 &&
            g.correlationScore >= 70
        ) {
            severity = 10;
        }
        // Coordinated voting anomaly
        else if (
            g.voteSpikePercent >= 60 &&
            g.correlationScore >= 60
        ) {
            severity = 7;
        }
        // Proposal frequency anomaly
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
