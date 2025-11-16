# Insider Governance Manipulation Trap 

A Drosera-compatible, stateless governance threat‑detection trap designed to identify proposal and voting patterns that resemble insider behavior, burner-wallet attacks, or coordinated whale governance manipulation.

---

## Purpose

This trap evaluates **off-chain governance intelligence**—such as proposer behavior, vote timing, and wallet provenance—to detect governance events that statistically match known attack patterns.

It is intentionally **stateless**, extremely **planner-safe**, and optimized for low-cost Drosera operation.

---

## Data Model: GovSummary

The off-chain agent submits a single encoded struct:

```solidity
struct GovSummary {
    uint64 proposerAgeDays;
    bool fundedFromCEX;
    uint32 proposalFrequency30d;
    uint32 avg30d;
    uint16 voteSpikePercent;
    uint16 correlationScore;
}
```

All expensive analysis—wallet age, funding heuristics, clustering, frequency analysis—is done off-chain.

---

## Detection Logic

The trap returns a severity score based on risk patterns:

### **Severity 10 (Critical)**

* Wallet age < 7 days
* Funded from a CEX
* > 70% of votes in one block

### **Severity 7 (High)**

* correlationScore > 80
  **OR**
* proposalFrequency > 2× 30‑day baseline

### **Severity 5 (Medium)**

* Wallet age < 7
* correlationScore > 60
* voteSpikePercent > 50

### **Severity 0** — Normal behavior

If severity > 0, the trap emits a payload for responders.

---

## Payload

```solidity
abi.encode(
    severity,
    proposerAgeDays,
    fundedFromCEX,
    proposalFrequency30d,
    avg30d,
    voteSpikePercent,
    correlationScore,
    block.number,
    block.timestamp
);
```

---

## Planner Safety

* `collect()` returns empty
* Safe decoding via `try/catch`
* No external calls
* No persistent storage writes

---

## Responder

The `InsiderGovernanceResponder` receives alert payloads and, depending on severity, can:

* Emit structured monitoring events
* Call a guardian/pause module
* Perform higher-level protective logic

---

## Off‑Chain Agent Requirements

* Monitor proposals & vote events
* Compute wallet age + funding source
* Analyze proposal frequency
* Detect vote-spike distribution
* Correlate proposer/voters
* Encode & submit a `GovSummary`

---

## License

MIT
