// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./interfaces/ITrap.sol";

contract InsiderGovernanceManipulationTrap is ITrap {
    /* -------------------------------------------------------------------------- */
    /*                                   Types                                    */
    /* -------------------------------------------------------------------------- */

    /// Summary metrics computed off-chain for a single governance proposal / vote event
    struct GovSummary {
        uint64 proposerAgeDays;        // Age of proposer wallet in days
        bool fundedFromCEX;            // Heuristic: true if last major funding source is CEX
        uint32 proposalFrequency30d;   // Number of proposals in last 30 days by this wallet
        uint32 avg30d;                 // Average number of proposals per similar account in 30 days
        uint16 voteSpikePercent;       // % of total votes arriving in single block (0–100)
        uint16 correlationScore;       // 0–100: proposer↔voter correlation index
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event InsiderGovernanceAlert(
        uint8 indexed severity,
        uint64 proposerAgeDays,
        bool fundedFromCEX,
        uint32 proposalFrequency30d,
        uint32 avg30d,
        uint16 voteSpikePercent,
        uint16 correlationScore,
        uint256 blockNumber,
        uint64 timestamp,
        address triggeredBy
    );

    /* -------------------------------------------------------------------------- */
    /*                                Trap Config                                 */
    /* -------------------------------------------------------------------------- */

    
    // “High risk” condition thresholds
    uint64 public constant MAX_NEW_WALLET_DAYS = 7;
    uint16 public constant HIGH_SPIKE_PERCENT = 70; 
    uint16 public constant MEDIUM_SPIKE_PERCENT = 50;

    uint16 public constant HIGH_CORRELATION = 80;
    uint16 public constant MEDIUM_CORRELATION = 60;

    uint32 public constant FREQUENCY_MULTIPLIER = 2; 

    /* -------------------------------------------------------------------------- */
    /*                                  COLLECT                                   */
    /* -------------------------------------------------------------------------- */

   
    function collect() external view override returns (bytes memory) {
        return "";
    }

    /* -------------------------------------------------------------------------- */
    /*                               SHOULD RESPOND                               */
    /* -------------------------------------------------------------------------- */

  
    function shouldRespond(bytes[] calldata data)
        external
        override
        returns (bool, bytes memory)
    {
        
        if (data.length == 0 || data[0].length == 0) {
            return (false, "");
        }

        GovSummary memory g;

        
        try this._safeDecode(data[0]) returns (GovSummary memory gs) {
            g = gs;
        } catch {
            
            return (false, "");
        }

        uint8 severity = 0;
        bytes memory reason;

        // ---------------------------------------------------------------------
        // 1. High-risk pattern (red flag)
        //    - wallet age < 7 days
        //    - funded from CEX
        //    - > 70% of votes in a single block
        // ---------------------------------------------------------------------
        if (
            g.proposerAgeDays < MAX_NEW_WALLET_DAYS &&
            g.fundedFromCEX &&
            g.voteSpikePercent > HIGH_SPIKE_PERCENT
        ) {
            severity = 10;
            reason = bytes("High-risk governance manipulation pattern detected");
        }
        // ---------------------------------------------------------------------
        // 2. Strong suspicion:
        //    - correlation very high OR proposal frequency much higher than baseline
        // ---------------------------------------------------------------------
        else if (
            g.correlationScore > HIGH_CORRELATION ||
            (g.avg30d > 0 && g.proposalFrequency30d > FREQUENCY_MULTIPLIER * g.avg30d)
        ) {
            severity = 7;
            reason = bytes("Suspicious proposer/voter correlation or abnormal proposal frequency");
        }
        // ---------------------------------------------------------------------
        // 3. Medium suspicion / anomaly:
        //    - any of: young wallet, medium vote spike, medium correlation
        // ---------------------------------------------------------------------
        else if (
            g.proposerAgeDays < MAX_NEW_WALLET_DAYS ||
            g.voteSpikePercent > MEDIUM_SPIKE_PERCENT ||
            g.correlationScore > MEDIUM_CORRELATION
        ) {
            severity = 5;
            reason = bytes("Minor governance anomaly detected");
        } else {
            
            return (false, "");
        }

        uint64 ts = uint64(block.timestamp);
        uint256 blk = block.number;

        // Build payload for responder(s)
        bytes memory payload = abi.encode(
            severity,
            g.proposerAgeDays,
            g.fundedFromCEX,
            g.proposalFrequency30d,
            g.avg30d,
            g.voteSpikePercent,
            g.correlationScore,
            blk,
            ts
        );

        emit InsiderGovernanceAlert(
            severity,
            g.proposerAgeDays,
            g.fundedFromCEX,
            g.proposalFrequency30d,
            g.avg30d,
            g.voteSpikePercent,
            g.correlationScore,
            blk,
            ts,
            msg.sender
        );

        return (true, payload);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Safe Decoder                           */
    /* -------------------------------------------------------------------------- */

   
    function _safeDecode(bytes calldata blob)
        external
        pure
        returns (GovSummary memory)
    {
        return abi.decode(blob, (GovSummary));
    }
}

