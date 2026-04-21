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

Feeders come in two flavors and a single trap may use both:

- **Analytics feeder** — populated by off‑chain analytics with time‑sensitive data (latest price snapshot, rolling averages, mempool signals). The trap reads the latest record in `collect()`.
- **Config feeder** (a.k.a. **BaselineFeeder**) — populated by governance with slow‑moving expected baselines (expected masterCopy, expected threshold, expected owners hash). Exists because `pure shouldRespond()` cannot read state, so baselines must flow through the snapshot. See §5 "BaselineFeeder Pattern".

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
(blockNumber, monitoredTarget, metrics...)
```

Operators pass samples to the trap:

```
data[0] → newest snapshot
data[1..n] → previous snapshots
```

The trap compares snapshots to detect anomalies.

### Required Snapshot Fields

Every Snapshot struct **must** include:

- `uint256 blockNumber` — the block at which `collect()` ran. Enables sample‑ordering validation (Section 5) and lets the responder record `currentBlockNumber` / `previousBlockNumber` on each incident.
- The **monitored target address** (e.g. `address safeProxy`, `address pool`, `address oracle`). `shouldRespond()` is `pure` and cannot read immutable storage, so without this the responder has no way to bind an incident to a specific target. A responder receiving `safeProxy = address(0)` cannot tell which wallet to pause.

Populate these in `collect()` from `block.number` and the trap's immutable target address.

```solidity
struct Snapshot {
    address monitoredTarget;    // REQUIRED
    uint256 blockNumber;        // REQUIRED
    // ... protocol-specific metrics
}
```

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

### Explicit Read‑Status Flags (Prefer over Sentinel Values)

A common pattern is to return `address(0)` (or `0`, or `bytes32(0)`) when a read fails. This is ambiguous: the responder cannot distinguish "the read failed" from "the value is legitimately zero." For critical fields, pair every fallible read with an explicit `bool xxxReadOk` flag:

```solidity
// Weak — address(0) overloaded as both "read failed" and "no value"
function _readGuard(address safe) internal view returns (address) {
    try ISafe(safe).getStorageAt(GUARD_SLOT, 1) returns (bytes memory r) {
        if (r.length >= 32) return address(uint160(uint256(bytes32(r))));
    } catch {}
    return address(0);
}

// Better — explicit status flag
function _readGuard(address safe) internal view returns (bool ok, address guard) {
    try ISafe(safe).getStorageAt(GUARD_SLOT, 1) returns (bytes memory r) {
        if (r.length >= 32) return (true, address(uint160(uint256(bytes32(r)))));
        return (false, address(0));
    } catch {
        return (false, address(0));
    }
}
```

With read‑status flags, `shouldRespond()` can treat **loss of visibility** as its own actionable threat (`MonitoringDegraded`) — an attacker who breaks the trap's RPC path or DoS‑es a read should not silently disable your detection. Failing closed is safer than failing open.

This rule applies to **token balance reads too**, not just protocol‑specific getters. A bare `IERC20(token).balanceOf(account)` returns `0` on any failure (token contract missing, RPC degradation, unexpected ABI change), which is ambiguous with a legitimate zero balance and — worse — can masquerade as a balance drain:

```solidity
// Weak — failed read looks like a drain
function _balanceOf(address token, address who) internal view returns (uint256) {
    try IERC20(token).balanceOf(who) returns (uint256 b) { return b; } catch {}
    return 0;
}

// Better — paired ok flag; aggregate only sums successful reads
function _balanceOf(address token, address who)
    internal view returns (bool ok, uint256 bal)
{
    if (token == address(0)) return (true, 0);
    try IERC20(token).balanceOf(who) returns (uint256 b) { return (true, b); }
    catch { return (false, 0); }
}
```

Aggregate balance fields (`aggregateBalance = ethBal + stethBal + methBal + ...`) must be built only from reads whose `ok` flag is true, and the snapshot must carry a `balancesReadOk` flag that drives `MonitoringDegraded`. Drain‑style relative checks (`BalanceDrain`, `GradualDrain`) must additionally be gated on the **previous**/**oldest** sample's `balancesReadOk` — a recovering RPC returning real balances after a degraded window must never look like a drain.

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

### Completeness Tracking

A bare `break` on catch or on hitting the page cap silently treats an incomplete read as "done." This is unsafe: a catch after reading 2 of 5 pages looks indistinguishable from a wallet with 2 modules. Return an explicit `complete` flag so the caller can tell a truthful empty list from a truncated one:

```solidity
function _readModules(address safe)
    internal view
    returns (bool complete, uint256 count, bytes32 hash)
{
    address start = SENTINEL;
    bytes32 runningHash = bytes32(0);
    uint256 total = 0;

    for (uint256 page = 0; page < MAX_PAGES; page++) {
        try ISafe(safe).getModulesPaginated(start, PAGE_SIZE)
            returns (address[] memory items, address next)
        {
            total += items.length;
            runningHash = keccak256(abi.encode(runningHash, items));
            if (next == SENTINEL || next == address(0) || items.length == 0) {
                return (true, total, runningHash); // reached end cleanly
            }
            start = next;
        } catch {
            return (false, total, runningHash);   // partial read
        }
    }
    return (false, total, runningHash);            // hit page cap
}
```

Treat `complete == false` as degraded monitoring (Section 4 "Explicit Read‑Status Flags"). Do not fire a relative module‑change threat on an incomplete read — the absent pages will look like modules vanished.

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

### Malformed‑Bytes Safety

Empty‑bytes guards are necessary but not sufficient. `abi.decode(bytes, (Snapshot))` **reverts** on non‑empty but malformed input (wrong length, invalid bool byte, garbage payload). A reverting `shouldRespond()` brings down the whole operator consensus call at the exact moment you want graceful fail‑closed behavior.

For production traps, prefer a length check + manual slot parsing over `abi.decode` on the snapshot:

```solidity
// Snapshot is all-static (no dynamic tails): fieldCount * 32 bytes
uint256 internal constant ENCODED_SNAPSHOT_LEN = FIELD_COUNT * 32;

function _decodeSnapshot(bytes calldata raw) internal pure returns (Snapshot memory s) {
    if (raw.length != ENCODED_SNAPSHOT_LEN) return s;     // graceful zero snapshot
    assembly {
        let p := raw.offset
        mstore(add(s, 0x00), calldataload(add(p, 0x00)))  // field 0
        mstore(add(s, 0x20), calldataload(add(p, 0x20)))  // field 1
        // ... one calldataload per field
    }
}
```

Permissive bool decode (`word != 0`) keeps the parser total — no input of the expected length can ever revert. Combine with the empty‑bytes guard above and an "empty previous sample is benign" policy (return `(false, "")` and skip relative checks) so a single bad sample cannot take down the consensus round.

This also applies to any nested decoding in `details` payloads — wrap them in helper functions that return safe defaults rather than letting `abi.decode` propagate.

### Strict Sample Ordering Validation

Drosera operators pass `data[0]` as newest and `data[n-1]` as oldest, expected to be contiguous. **Do not trust this** — malformed, reordered, or gapped samples will poison comparison logic (a "drain" detected across a 1000‑block gap is meaningless). Validate explicitly:

```solidity
// Require newest → oldest, strictly contiguous, no zero-block samples
for (uint256 i = 1; i < data.length; i++) {
    Snapshot memory newer = abi.decode(data[i - 1], (Snapshot));
    Snapshot memory older = abi.decode(data[i],     (Snapshot));
    if (
        newer.blockNumber == 0 ||
        older.blockNumber == 0 ||
        newer.blockNumber != older.blockNumber + 1
    ) {
        return (false, ""); // malformed window, do not evaluate
    }
}
```

Also validate that every sample refers to the same monitored target:

```solidity
if (current.monitoredTarget == address(0) ||
    previous.monitoredTarget != current.monitoredTarget) {
    return (false, "");
}
```

This is why Section 3.2 requires `blockNumber` and `monitoredTarget` in every Snapshot.

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

### Absolute vs Relative Integrity Checks

Detection logic falls into two categories. A production trap needs both:

**Absolute checks** compare current state against a known‑good baseline (expected masterCopy, expected threshold, expected owners hash) supplied by a governance‑owned config contract:

```solidity
if (current.baselineConfigured &&
    current.masterCopy != current.expectedMasterCopy) {
    return _incident(ThreatType.MasterCopyChanged, ...);
}
```

**Relative checks** compare current against previous snapshot (guard changed, modules changed, balance dropped):

```solidity
if (current.guard != previous.guard) {
    return _incident(ThreatType.GuardChanged, ...);
}
```

Using only relative checks misses attacks that were already present when the trap was deployed — if the masterCopy was already swapped at deploy time, `current == previous` and nothing fires. Using only absolute checks misses incremental drift that wasn't anticipated. Combine them: absolute checks first (baseline integrity), relative checks second (change detection).

### BaselineFeeder Pattern (Governance‑Driven Config for `pure shouldRespond`)

`shouldRespond()` is `pure` — it cannot read contract state, cannot read immutables, and cannot access `address(this)`. Hardcoding baselines as `constant` compiles but is deployment‑fragile: every monitored target needs a bespoke build, baseline rotation means redeploying code, and source‑edit‑driven config is not what teams mean by production‑ready infrastructure.

The correct pattern is a governance‑owned **BaselineFeeder** contract that the trap reads in `collect()` and **embeds the expected values into every snapshot**. `shouldRespond()` then consumes them from the sample bytes, staying `pure`:

```solidity
interface IBaselineFeeder {
    struct Baseline {
        address masterCopy;
        uint256 threshold;
        uint256 ownerCount;
        bytes32 ownersHash;
        bool configured;
    }
    function getBaseline(address target) external view returns (Baseline memory);
}

// inside collect():
bool cfg; address expMC; uint256 expThr; uint256 expOC; bytes32 expOH;
try IBaselineFeeder(BASELINE_FEEDER).getBaseline(TARGET) returns (
    IBaselineFeeder.Baseline memory b
) {
    cfg = b.configured; expMC = b.masterCopy;
    expThr = b.threshold; expOC = b.ownerCount; expOH = b.ownersHash;
} catch { /* cfg stays false */ }

return abi.encode(Snapshot({
    /* ... observed values ... */
    baselineConfigured: cfg,
    expectedMasterCopy: expMC,
    expectedThreshold:  expThr,
    expectedOwnerCount: expOC,
    expectedOwnersHash: expOH
}));
```

Rotation happens on‑chain via `feeder.setBaseline(target, mc, thr, oc, ownersHash)` behind a governance multisig + timelock — no trap redeploy. A reading failure or an unconfigured target sets `baselineConfigured = false`, and `shouldRespond()` must skip absolute checks in that case (relative checks still fire).

Do **not** read the baseline on‑chain at deployment from the target itself — an attacker who controls state at deploy time would pin the baseline to the compromised value. The feeder's write path must be governance‑controlled, independent of the monitored target.

### Structured Incident Payloads

Loose `abi.encode(uint8 threatType, bytes details)` works but is not self‑describing — the responder has to know the positional shape out‑of‑band, and `details` varies per threat type. For production traps, define a named struct and encode that:

```solidity
struct IncidentPayload {
    ThreatType threatType;            // enum-backed uint8
    address monitoredTarget;          // which safe/pool/oracle
    uint256 currentBlockNumber;
    uint256 previousBlockNumber;
    bytes details;                    // threat-specific extras
}

return (true, abi.encode(IncidentPayload({
    threatType: ThreatType.MasterCopyChanged,
    monitoredTarget: current.monitoredTarget,
    currentBlockNumber: current.blockNumber,
    previousBlockNumber: previous.blockNumber,
    details: abi.encode(current.expectedMasterCopy, current.masterCopy)
})));
```

Matching responder signature:

```solidity
function handleIncident(bytes calldata rawPayload) external;
```

Benefits:
- Self‑describing — one named field per piece of context
- Stable ABI — add fields at the end without breaking existing decoders
- Easy idempotency — `keccak256(rawPayload)` is a natural incident ID
- Cleaner logs — responder emits each field as an indexed event arg

Keep `details` as `bytes` for threat‑specific extras rather than bloating the base struct.

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

### Idempotent Execution

A responder may receive the same incident more than once — an operator retry, a relayer re‑submission, a chain reorg. Executing the downstream pause twice is best‑case wasteful and worst‑case harmful (double‑billed fees, inconsistent state, event spam). Make `handleIncident` idempotent by deduplicating on the payload hash:

```solidity
mapping(bytes32 => bool) public executedIncidentHash;

function handleIncident(bytes calldata rawPayload) external onlyAuthorized {
    bytes32 incidentHash = keccak256(rawPayload);
    if (executedIncidentHash[incidentHash]) return;   // already handled
    executedIncidentHash[incidentHash] = true;

    // ... execute response
}
```

The same payload hashing to the same ID guarantees a retry is a no‑op. Note this is a dedup, not a rate‑limiter — for rate limiting use a cooldown block window.

### Guardian Registry (Fan‑Out Pattern)

A responder hardcoded to one downstream target is a single point of failure and a deployment‑time commitment. Production responders should **fan out to a bounded allowlist of approved emergency targets** managed by an owner/governance address:

```solidity
contract SafeGuardianRegistry {
    uint256 public constant MAX_TARGETS = 16;         // bounds fan-out gas

    address public owner;
    mapping(address => bool) public approvedTargets;
    mapping(address => bool) internal _seen;          // ever pushed?
    address[] public targets;

    function setTarget(address target, bool approved) external onlyOwner {
        require(target != address(0), "zero target");
        if (!_seen[target]) {
            require(targets.length < MAX_TARGETS, "max targets");
            _seen[target] = true;
            targets.push(target);                     // push at most once
        }
        approvedTargets[target] = approved;
    }
    function getTargets() external view returns (address[] memory) { return targets; }
}

interface IEmergencyActionTarget {
    function emergencyPause(bytes calldata incidentPayload) external;
}

// inside responder.handleIncident():
address[] memory targets = registry.getTargets();
for (uint256 i = 0; i < targets.length; i++) {
    if (!registry.approvedTargets(targets[i])) continue;
    try IEmergencyActionTarget(targets[i]).emergencyPause(rawPayload) {
        emit DownstreamPauseAttempt(targets[i], true);
    } catch {
        emit DownstreamPauseAttempt(targets[i], false);
    }
}
```

Two subtleties worth calling out:

- **Duplicate protection.** A naïve `if (approved && !approvedTargets[target]) targets.push(target)` re‑pushes a target after a `revoke → re‑approve` cycle, producing a duplicate in `targets[]` and therefore duplicate downstream calls when the responder fans out. Track insertion separately with a `_seen` flag, as shown above. `approvedTargets` stays the live flag gating fan‑out; `targets[]` is append‑only for stable off‑chain indexing.
- **Bounded fan‑out.** The responder iterates `targets[]` inside a single on‑chain call. Without an explicit cap (`MAX_TARGETS`), a registry that has been appended to many times becomes gas‑fragile at the exact moment you need it most — an incident. If you expect more than ~16 distinct targets, shard responders by domain (core, treasury, bridges, ...) rather than growing one unbounded list.

This gives governance the ability to add, rotate, or remove emergency hooks without redeploying the responder — and isolates a single misbehaving target so it cannot prevent the others from being paused.

### Governance‑Compatible vs Governance‑Managed

A registry + feeder + responder tuple with `owner`/`admin`/`relayer` fields is **governance‑compatible**: the code allows a multisig + timelock to take those roles. Whether the system is actually **governance‑managed** depends on the deployment — an EOA as owner is governance‑compatible but not governance‑managed. Production submissions should deploy all privileged roles behind a real multisig + timelock and state in their README that this is an operational property, not a property of the source alone.

### Additional Protections

Optional protections:

• cooldown periods
• multi‑sig approval for unpausing
• escalation tiers
• global pause switch on the responder itself (kill‑switch for false‑positive storms)

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
- [ ] Snapshot includes `blockNumber` and the monitored target address
- [ ] Every fallible read has an explicit `xxxReadOk` flag (no ambiguous `address(0)` sentinels)
- [ ] Token balance reads return `(ok, bal)`; aggregate fields only sum successful reads; snapshot carries a `balancesReadOk` flag that drives `MonitoringDegraded`
- [ ] Drain‑style relative checks are gated on the previous/oldest sample's `balancesReadOk` so a recovering RPC cannot look like a drain
- [ ] Paginated reads track completeness (`complete` flag) and do not silently treat partial reads as empty
- [ ] `shouldRespond()` is `external pure`
- [ ] `shouldRespond()` validates strict newest→oldest contiguous sample ordering
- [ ] `shouldRespond()` validates every sample refers to the same monitored target
- [ ] `shouldRespond()` decodes samples and applies deterministic logic only
- [ ] `shouldRespond()` is safe against **malformed** (non‑empty, wrong‑length, garbage) snapshot bytes — length check + manual parsing, not raw `abi.decode`
- [ ] Both absolute (vs baseline) and relative (vs previous) integrity checks are present
- [ ] Baseline `(masterCopy, threshold, ownerCount, ownersHash, ...)` is read from a governance‑owned feeder at `collect()` time and embedded in every snapshot; absolute checks are gated on `baselineConfigured`; baseline rotation needs no trap redeploy
- [ ] All inputs validated — empty arrays, invalid data, zero‑length bytes handled safely

### Payload & Response Alignment
- [ ] `shouldRespond()` payload ABI‑decodes to `response_function` parameter types exactly
- [ ] Trap output shape matches TOML `response_function` signature
- [ ] Response contract parameters match the payload encoding
- [ ] Response contract deployed and accessible
- [ ] Responder auth allows the actual Drosera executor address(es)
- [ ] Responder is idempotent (dedup on incident hash) — replaying the same incident is a no‑op
- [ ] For multi‑target containment: approved targets managed via registry/allowlist, not hardcoded
- [ ] Registry caps total targets at `MAX_TARGETS` so fan‑out gas is bounded
- [ ] Registry uses a `_seen` insertion flag so `revoke → re‑approve` cannot duplicate a target in the array or cause duplicate downstream calls
- [ ] Privileged roles (feeder owner, registry owner, responder admin) are deployed behind a governance multisig + timelock, not EOAs — code is governance‑*compatible*, deployment makes it governance‑*managed*

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
