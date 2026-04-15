# MASTER GUIDELINES.md

## Building Production-Grade Drosera Traps (Ethereum Mainnet)

This document consolidates best practices from multiple Drosera trap development guides into a single **master reference** for building secure, deterministic, and production‑ready traps on Ethereum mainnet.

It covers architecture, contract design rules, safety practices, testing, deployment, and operational patterns.

---

# 0. Operation Flytrap — PoC Submission Standard

All trap submissions must follow the **Operation Flytrap** standard: high‑fidelity Proof of Concepts demonstrating how Drosera would have contained or mitigated a specific, high‑impact historical exploit.

## 0.1 Two‑Part Submission Structure

Every submission has two mandatory parts:

### Part 1 — Reproduction of Exploit (Proof)

A concise, self‑contained code block (Foundry test / Solidity) demonstrating the **exact state transition** of the chosen historical exploit.

- Must be executable — `forge test` must pass
- Fork mainnet at the real exploit block using `vm.createFork()`
- Show the attack step‑by‑step: setup → exploit → resulting state
- Assert the damage: `assertEq(attackerBalance, stolenAmount)`, `assertTrue(protocolDrained)`

### Part 2 — The Trap (Mitigation Proof)

The trap must encode a **clear, binary detection of failure**.

- `shouldRespond()` must return `true` when the exploit condition is detected
- The returned `bytes` payload must clearly encode the reason or context (e.g., an invariant identifier)
- The response path must demonstrate how damage would have been contained (pause, freeze, alert)

Example outcome:
```
[TRIGGERED: InvariantBroke()]
```

Submissions must make it unambiguous:
- **What invariant** is being enforced
- **How it is measured** across blocks
- **Why a trigger** represents a real incident

## 0.2 "Show Your Work" Commenting Standard

Code comments must **map lines of the exploit to lines of the detection logic**. A reviewer should be able to trace from "this is the attack step" to "this is how the trap catches it."

```solidity
// EXPLOIT: Attacker swaps Safe masterCopy to malicious implementation (block 21,895,238)
// DETECTION: collect() probes getThreshold() — after swap, all Safe functions revert
//            shouldRespond() sees implementationValid == false → triggers response
```

Every trap must include comments that:
- Describe the attack vector being monitored
- Identify the specific on‑chain state change the exploit causes
- Explain why the detection logic catches that state change
- Note the response window (how many blocks between detection and damage)

## 0.3 "By the Book" Completeness Checklist

A submission is not complete unless it includes **all** of the following:

| # | Requirement | Details |
|---|---|---|
| 1 | **Threat model** | Clear statement of what is monitored and what attack it catches |
| 2 | **collect()** | `view`, structured `abi.encode(CollectOutput(...))`, safe reads, no fragility |
| 3 | **shouldRespond()** | `pure`, decode samples, deterministic logic, return `(bool, bytes)` |
| 4 | **Response payload alignment** | Trap output ↔ TOML `response_function` signature ↔ response contract parameters must all match |
| 5 | **Edge case handling** | Empty arrays, invalid data, division by zero, reverted reads, inconsistent state — fail safely, never revert |
| 6 | **Deterministic logic** | On‑chain readable state only, no randomness, no off‑chain assumptions |
| 7 | **Response path** | Response contract + target function + defined action + correct permissions (a trap without a response path is only a monitor) |
| 8 | **Configuration** | `drosera.toml` with trap path, response contract, response function, block sample size, cooldown, operator settings, network config |
| 9 | **Tests** | Normal behavior, trigger behavior, edge cases, sample ordering, boundary thresholds |
| 10 | **Documentation** | Use case / historical event, problem solved, how it works, assumptions, limitations |

## 0.4 What We Explicitly Reject

The following will **not** be accepted as submissions:

- Abstract descriptions of security layers without executable code
- Non‑technical sequence diagrams
- AI‑generated vulnerability reports without working Foundry tests
- Submissions relying on discretionary off‑chain monitoring, subjective operator judgment, or human‑in‑the‑loop intervention
- Traps without a response path (detection alone is insufficient)

Submissions **may** rely on a trust‑minimized keeper or operator network only where it executes a specific, predetermined response payload derived from the trap logic.

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
• Return data in a **structured, encoded format** using a defined struct

If an external dependency fails, return safe defaults.

### Structured Output Pattern

Define a struct for your collected data and always return `abi.encode(CollectOutput(...))`:

```solidity
struct CollectOutput {
    uint256 blockNumber;
    uint256 totalBalance;
    address implementation;
    bool functionCallsSucceed;
}

function collect() external view override returns (bytes memory) {
    // Gather on-chain data with safe defaults
    uint256 balance = address(MONITORED).balance;
    address impl = _safeGetImplementation();
    bool healthy = _probeHealthCheck();

    return abi.encode(CollectOutput({
        blockNumber: block.number,
        totalBalance: balance,
        implementation: impl,
        functionCallsSucceed: healthy
    }));
}
```

This structured approach ensures `shouldRespond()` can cleanly decode samples and apply deterministic comparisons.

### Safe Fallback Pattern

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

### Reading Storage Slots

Some protocols expose `getStorageAt()` for reading arbitrary storage slots. This is useful for monitoring proxy implementation addresses (slot 0), guard addresses, or other internal state that may not have a getter:

```solidity
try IContract(target).getStorageAt(SLOT, 1) returns (bytes memory result) {
    if (result.length >= 32) {
        return address(uint160(uint256(bytes32(result))));
    }
} catch {}
return address(0); // safe default on failure
```

Always wrap in try/catch — `getStorageAt` may not be available on all contracts or may behave differently in Foundry fork contexts.

### Paginated Data Collection

When collecting linked‑list or paginated data (e.g., Safe modules), iterate all pages rather than reading only the first. Bound the loop to prevent infinite iteration:

```solidity
for (uint256 page = 0; page < MAX_PAGES; page++) {
    try IContract(target).getPaginated(start, PAGE_SIZE)
        returns (address[] memory items, address next)
    {
        // process items
        if (next == SENTINEL || next == address(0)) break;
        start = next;
    } catch { break; }
}
```

Reading only the first page can miss changes — an attacker could add a malicious entry beyond page boundaries.

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

### Payload Must Match Response Function

The bytes returned by `shouldRespond()` are passed directly as arguments to the response function configured in `drosera.toml`. The payload shape must match the response function signature exactly.

Bad — payload shape varies per code path:
```solidity
// Path A returns (string, uint256, uint256)
return (true, abi.encode("balance drain", prev, curr));
// Path B returns (string, address, address)
return (true, abi.encode("impl changed", expected, actual));
```

Good — consistent shape matching `handleIncident(uint8,bytes)`:
```solidity
return (true, abi.encode(uint8(THREAT_BALANCE_DRAIN), abi.encode(prev, curr)));
return (true, abi.encode(uint8(THREAT_IMPL_CHANGED), abi.encode(expected, actual)));
```

If the payload does not ABI‑decode to the response function's parameter types, the on‑chain callback will revert silently — your trap detects the incident but the response never executes.

### Using the Full Data Window

`shouldRespond()` receives `data[0..n]` where `data[0]` is newest and `data[n-1]` is oldest. Most checks compare consecutive pairs (`data[0]` vs `data[1]`), but cumulative analysis across the full window catches slow‑moving threats:

```solidity
// Gradual drain: compare newest vs oldest
if (data.length > 2) {
    Snapshot memory oldest = abi.decode(data[data.length - 1], (Snapshot));
    uint256 cumulativeDrop = oldest.balance - current.balance;
    // fire if cumulative drop exceeds threshold
}
```

Set `block_sample_size` in `drosera.toml` large enough to support window‑based analysis (e.g., 10 blocks for a 15% cumulative drain check).

### Multi‑Vector Detection

When a trap monitors multiple independent threat vectors, order checks by severity and short‑circuit on the first detection:

```solidity
// 1. Most critical first
if (!current.implementationValid) return (true, ...);
// 2. Next most critical
if (current.masterCopy != EXPECTED) return (true, ...);
// ...
// N. Lowest severity last
if (nonceJump > MAX) return (true, ...);
```

This ensures the most important signal is always reported. Note that short‑circuiting means only one vector is reported per block — if multiple fire simultaneously, lower‑priority ones are hidden until the first is resolved.

---

# 6. Data Encoding Strategy

Snapshots should be **compact and efficient**.

Recommendations:

• Use **basis points (bps)** for percentages
• Use smaller integer types (`uint16`, `uint32`)
• Avoid large dynamic arrays
• Hash large datasets when needed
• Name fields honestly — don't call a raw token sum "totalValue" if it's not a normalized market valuation; use `aggregateBalance` or similar

### Hashing Variable‑Length Data

When monitoring lists that can change (owners, modules, approvals), store a hash rather than the full array. This makes snapshot comparison a single `bytes32` equality check:

```solidity
bytes32 ownersHash = keccak256(abi.encode(ISafe(safe).getOwners()));
```

For paginated data that spans multiple pages, use **incremental hashing** to avoid dynamic array expansion:

```solidity
bytes32 runningHash = bytes32(0);
address start = address(0x1); // sentinel

for (uint256 page = 0; page < MAX_PAGES; page++) {
    (address[] memory items, address next) =
        ISafe(safe).getModulesPaginated(start, PAGE_SIZE);
    runningHash = keccak256(abi.encode(runningHash, items));
    if (next == address(0x1) || next == address(0)) break;
    start = next;
}
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

**A trap is not complete without a response path.** A trap without a response contract is only a monitor — it detects but cannot contain. Every submission must include a response contract with a target function, a clearly defined action, and correct permissions.

All side effects belong in the responder.

Typical responses:

• pause borrowing
• freeze treasury actions
• revoke admin privileges
• emit alerts

### Response Function Interface

For traps that detect multiple threat types, use a generic interface rather than a narrow one:

```solidity
// Flexible — works for any number of threat vectors
function handleIncident(uint8 threatType, bytes calldata details) external;

// Too narrow — only fits implementation-swap scenarios
function emergencyPause(address reportedImpl, address expectedImpl) external;
```

The trap's `shouldRespond()` payload must ABI‑decode to the response function's parameter types exactly. This is the most common integration failure.

### Authorization Model

In Drosera, the `msg.sender` that calls your response function is the address that **submits the response transaction on‑chain**. This may be an operator EOA, a relayer, a protocol executor, or an aggregation contract — it is **not** guaranteed to be a single fixed address.

A single‑address check will silently break if the actual executor differs:

```solidity
// Fragile — breaks if the actual caller is not exactly this address
require(msg.sender == droseraOperator, "UNAUTHORIZED");
```

Prefer an **allowlist** so you can authorize multiple executors:

```solidity
mapping(address => bool) public allowedCallers;

modifier onlyAllowed() {
    require(allowedCallers[msg.sender], "not allowed");
    _;
}

function setAllowed(address caller, bool allowed) external onlyAdmin {
    allowedCallers[caller] = allowed;
}
```

For demos and testing, removing auth entirely is also acceptable — the Drosera network already controls who can trigger responses via configuration.

### Additional Protections

Optional protections:

• cooldown periods
• multi‑sig approval for unpausing
• escalation tiers

---

# 10. drosera.toml Configuration

Every trap must include a proper `drosera.toml` defining all required fields.

### Required Fields

```toml
# Network configuration
ethereum_rpc = "https://rpc.mevblocker.io"
eth_chain_id = 1

# Drosera protocol address
drosera_address = "0xYourDroseraAddress"

[traps.your_trap]
# Trap artifact path (compiled contract JSON)
path = "out/YourTrap.sol/YourTrap.json"

# Response path (MANDATORY — a trap without these is only a monitor)
response_contract = "0xResponder"
response_function = "handleIncident(uint8,bytes)"

# Sampling configuration
block_sample_size = 8           # Number of blocks in the data window
cooldown_period_blocks = 20     # Blocks between consecutive triggers

# Operator configuration
min_number_of_operators = 1
max_number_of_operators = 5

# Privacy
private_trap = true
whitelist = []
```

### Critical Alignment Rule

The `response_function` signature in the TOML **must exactly match** the parameter types encoded by `shouldRespond()`. This is the most common integration failure:

```
trap shouldRespond() returns → abi.encode(uint8, bytes)
TOML response_function       → "handleIncident(uint8,bytes)"
response contract function    → function handleIncident(uint8 threatType, bytes calldata details)
```

All three must align. If they don't, the on‑chain callback reverts silently — the trap detects the incident but the response never executes.

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

## Required Test Categories

A proper trap must include tests covering all of the following:

### 1. Normal Behavior
Verify the trap does **not** trigger under healthy protocol conditions. Fork at a block where no exploit is occurring and confirm `shouldRespond()` returns `false`.

### 2. Trigger Behavior
Verify the trap **does** trigger when the exploit condition is present. Fork at the actual exploit block and confirm `shouldRespond()` returns `true` with the correct payload.

### 3. Edge Cases
Test boundary conditions and failure modes:
- Empty sample arrays → should return `(false, "")`
- Single sample (no comparison possible) → should return `(false, "")`
- Invalid or zero‑length encoded data → should not revert
- Division by zero scenarios → should fail safely

### 4. Sample Ordering
Verify correct behavior with the Drosera data ordering convention: `data[0]` = newest, `data[n-1]` = oldest. Test that swapping order does not produce false positives.

### 5. Boundary Thresholds
Test values at, just above, and just below detection thresholds:
- Threshold - 1 → should not trigger
- Threshold → should trigger (or not, depending on design — document which)
- Threshold + 1 → should trigger

### 6. Exploit Reproduction (Operation Flytrap)
A self‑contained test that replays the historical exploit step‑by‑step using `vm.createFork()` at the real block. Assert the damage occurred, then demonstrate the trap would have caught it.

## Deployment Workflow

Before deployment:

1. `forge build` — compile all contracts
2. Validate addresses with `cast code`
3. `drosera dryrun` — simulate trap execution locally
4. Confirm all test categories pass
5. Verify responder behavior and payload alignment

Never deploy without a successful dryrun.

---

# 14. Common Failure Causes

Typical trap failures include:

• `collect()` reverting
• decoding empty blobs
• incorrect addresses
• wrong network RPC
• invalid response contract
• **payload/response signature mismatch** — `shouldRespond()` returns bytes that don't ABI‑decode to the response function's parameter types, causing the on‑chain callback to revert silently
• **responder auth mismatch** — responder checks `msg.sender == X` but the actual Drosera executor is a different address, so the response transaction always reverts

Always guard inputs carefully.

---

# 15. Production Hardening Checklist

Before mainnet activation:

### Core Contract Requirements
- [ ] `collect()` is `external view` and cannot revert
- [ ] `collect()` returns structured `abi.encode(CollectOutput(...))` with safe defaults on failure
- [ ] `shouldRespond()` is `external pure`
- [ ] `shouldRespond()` decodes samples and applies deterministic logic only
- [ ] All inputs validated — empty arrays, invalid data, zero‑length bytes handled safely

### Payload & Response Alignment
- [ ] `shouldRespond()` payload ABI‑decodes to `response_function` parameter types exactly
- [ ] Trap output shape matches TOML `response_function` signature
- [ ] Response contract parameters match the payload encoding
- [ ] Response contract deployed and accessible
- [ ] Responder auth allows the actual Drosera executor address(es)

### Determinism & Safety
- [ ] No randomness, no off‑chain assumptions, no `msg.sender` dependencies
- [ ] Division by zero impossible or safely handled
- [ ] External reads wrapped in try/catch with safe defaults
- [ ] No storage writes, events, or state‑changing calls in trap

### Configuration
- [ ] `drosera.toml` includes: trap path, response contract, response function, block sample size, cooldown, operator settings, network config
- [ ] `block_sample_size` supports the detection window needed

### Testing
- [ ] Normal behavior tests pass (no false positives)
- [ ] Trigger behavior tests pass (detects the exploit)
- [ ] Edge case tests pass (empty data, boundaries, invalid input)
- [ ] Sample ordering tests pass
- [ ] Boundary threshold tests pass
- [ ] Exploit reproduction test passes (historical fork)

### Documentation
- [ ] Threat model documented (what is monitored, what attack it catches)
- [ ] Historical event / use case described
- [ ] Assumptions and limitations stated
- [ ] "Show Your Work" comments present — exploit lines mapped to detection logic

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

# 17. Documentation Requirements

Every trap submission must include documentation (README or inline) that covers:

### Required Sections

| Section | Content |
|---|---|
| **Historical Event** | Which exploit, when it happened, how much was lost |
| **Attack Description** | Step‑by‑step breakdown of what the attacker did |
| **Threat Model** | What the trap monitors, what attack or failure it catches |
| **Detection Logic** | How `collect()` gathers state and `shouldRespond()` identifies the anomaly |
| **Response Path** | What action the response contract takes and how it contains damage |
| **Response Window** | How many blocks between first detectable signal and damage — how early Drosera would have caught it |
| **Assumptions** | What the trap assumes (e.g., specific contract addresses, protocol behavior) |
| **Limitations** | What the trap does **not** protect against |

### Inline "Show Your Work" Comments

Beyond the README, the Solidity code itself must contain comments mapping exploit mechanics to detection logic (see Section 0.2).

---

# 18. Philosophy of a Good Trap

A strong Drosera trap:

• does not panic
• does not revert
• avoids false positives
• detects real anomalies
• escalates safely
• **proves its value** — a Forge test showing `assertEq(attackerBalance, 0)` after intervention is worth more than any diagram

Think of traps as **protocol safety systems**, not alarms. A trap that detects without a response path is incomplete. A trap that triggers without a clear invariant is noise.

The goal: a senior Solidity engineer or security researcher should be able to read the code, run the tests, and immediately understand what was caught, how, and why it matters.

---

# Final Principle

Traps detect signals.

Responders take action.

Tests prove both.

Keep them separated, deterministic, and provable.

---

End of Master Guidelines
