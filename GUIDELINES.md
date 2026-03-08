# MASTER GUIDELINES.md

## Building Production-Grade Drosera Traps (Ethereum Mainnet)

This document consolidates best practices from multiple Drosera trap development guides into a single **master reference** for building secure, deterministic, and production‑ready traps on Ethereum mainnet.

It covers architecture, contract design rules, safety practices, testing, deployment, and operational patterns.

---

# 1. Understand the Drosera Architecture

A Drosera monitoring system consists of four logical layers:

**Off‑chain Analytics → Feeder → Trap → Responder / Alert System**

### Off‑chain Analytics

Responsible for:

• Heavy computation
• Cross‑protocol analysis
• Time‑series aggregation
• Mempool monitoring
• Statistical modeling

### Feeder Contract

A minimal on‑chain storage layer that:

• Stores the latest computed snapshot
• Exposes a `view` getter for traps
• Is controlled by a trusted operator

### Trap Contract

The Drosera trap itself:

• Calls `collect()` to gather state
• Executes deterministic logic in `shouldRespond()` or `shouldAlert()`
• Returns `(bool, payload)` without side effects

### Responder / Alert Layer

Handles actions such as:

• Protocol pause
• Treasury freeze
• Governance escalation
• Webhook or Slack alerts

---

# 2. Core Drosera Execution Rules

Drosera traps must follow strict deterministic execution rules.

### Required Function Properties

```
collect()        → external view
shouldRespond()  → external pure
shouldAlert()    → external pure
```

### Forbidden Inside Traps

• Storage writes
• Events
• External state‑changing calls
• `msg.sender` dependencies
• Randomness
• reliance on mutable state

The same input must **always produce the same output**.

---

# 3. Trap Design Principles

## 3.1 Stateless Evaluation

Traps should not maintain state.

Prefer:

• `constant` configuration values
• Hardcoded monitored addresses
• Encoded snapshot comparisons

Avoid:

• mappings
• dynamic storage variables
• incremental counters

State belongs **outside the trap**.

---

## 3.2 Snapshot Pattern

The standard design pattern is **snapshot comparison**.

`collect()` returns a snapshot:

```
(timestamp, blockNumber, metrics...)
```

Operators pass samples to the trap:

```
data[0] → newest snapshot
data[1..n] → previous snapshots
```

The trap compares snapshots to detect anomalies.

---

# 4. Designing collect()

## Key Requirements

`collect()` must:

• Be `external view`
• Never revert
• Handle external failures gracefully

If an external dependency fails, return safe defaults.

### Safe Pattern

```solidity
function collect() external view override returns (bytes memory) {
    uint256 size;
    assembly { size := extcodesize(FEEDER) }
    if (size == 0) return bytes("");

    try IFeeder(FEEDER).getLatest() returns (Summary memory s) {
        return abi.encode(s);
    } catch {
        return bytes("");
    }
}
```

A reverting `collect()` will break:

• `drosera dryrun`
• operator execution
• trap sampling

---

# 5. Designing shouldRespond()

`shouldRespond()` performs the **decision logic only**.

It must:

• Be `external pure`
• Decode snapshot data
• Validate input sizes
• Return `(bool, payload)`

### Required Guards

```
if (data.length == 0 || data[0].length == 0)
    return (false, "");
```

Never assume valid input.

---

# 6. Data Encoding Strategy

Snapshots should be **compact and efficient**.

Recommendations:

• Use **basis points (bps)** for percentages
• Use smaller integer types (`uint16`, `uint32`)
• Avoid large dynamic arrays
• Hash large datasets when needed

Example:

```solidity
abi.encode(
    totalValue,
    largestAssetValue,
    concentrationScore
);
```

Efficient encoding improves operator performance.

---

# 7. Designing Good Signals

Avoid single‑threshold triggers.

Better signals combine:

• time‑series comparison
• multi‑metric evaluation
• sustained deviation checks

Examples:

• price divergence vs TWAP
• liquidity drop vs rolling average
• treasury concentration drift
• governance voting anomalies

Use **basis‑point thresholds** whenever possible.

---

# 8. Gas and Complexity Considerations

Even though traps are view‑only:

• operators execute them frequently
• inefficient logic slows monitoring

Avoid:

• large loops
• dynamic array scans
• expensive math

Prefer simple comparisons.

---

# 9. Response Contract Design

All side effects belong in the responder.

Typical responses:

• pause borrowing
• freeze treasury actions
• revoke admin privileges
• emit alerts

Protect the responder:

```solidity
modifier onlyCaller {
    require(msg.sender == caller, "UNAUTHORIZED");
    _;
}
```

Optional protections:

• cooldown periods
• multi‑sig approval
• escalation tiers

---

# 10. drosera.toml Configuration

Example mainnet configuration:

```toml
ethereum_rpc = "https://rpc.mevblocker.io"
eth_chain_id = 1

drosera_address = "0xYourDroseraAddress"

[traps.your_trap]
path = "out/YourTrap.sol/YourTrap.json"
response_contract = "0xResponder"
response_function = "handle(bytes)"
block_sample_size = 8
cooldown_period_blocks = 20
min_number_of_operators = 1
max_number_of_operators = 5
private_trap = true
```

Important:

• omit response fields if not using a responder

---

# 11. Project Structure

Recommended Foundry structure:

```
src/
  traps/
  feeders/
  responders/
  interfaces/

script/
  deploy/

test/

drosera.toml
```

Compile with:

```
forge build
```

---

# 12. Operator Setup

Operators run the trap monitoring loop.

Requirements:

• stable Ethereum RPC
• reliable server
• open networking port

Example run command:

```
drosera-operator node \
  --eth-rpc-url $ETH_RPC_URL \
  --eth-private-key $OPERATOR_PRIVATE_KEY \
  --drosera-address $DROSERA_ADDRESS
```

Ensure uptime monitoring is in place.

---

# 13. Testing Workflow

Before deployment:

1. `forge build`
2. Validate addresses (`cast code`)
3. Run `drosera dryrun`
4. Simulate edge cases
5. Test responder behavior

Never deploy without a successful dryrun.

---

# 14. Common Failure Causes

Typical trap failures include:

• `collect()` reverting
• decoding empty blobs
• incorrect addresses
• wrong network RPC
• invalid response contract

Always guard inputs carefully.

---

# 15. Production Hardening Checklist

Before mainnet activation:

• [ ] collect() cannot revert
• [ ] shouldRespond() is pure
• [ ] all inputs validated
• [ ] feeder returns expected struct
• [ ] thresholds tested
• [ ] response contract protected
• [ ] operators configured

---

# 16. Advanced Trap Patterns

More sophisticated traps may use:

• sliding window averages
• deviation scoring
• hysteresis thresholds
• multi‑source verification
• progressive escalation

Examples:

• oracle divergence traps
• governance manipulation detectors
• treasury concentration monitors
• cross‑chain bridge deviation traps

---

# 17. Philosophy of a Good Trap

A strong Drosera trap:

• does not panic
• does not revert
• avoids false positives
• detects real anomalies
• escalates safely

Think of traps as **protocol safety systems**, not alarms.

---

# Final Principle

Traps detect signals.

Responders take action.

Keep them separated, deterministic, and simple.

---

End of Master Guidelines
