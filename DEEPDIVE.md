# Drosera Deep Dive

## 1. What Problem Does Drosera Solve?

Smart contracts on Ethereum are powerful but fundamentally reactive. They sit on-chain waiting to be called — they can't watch what's happening around them, detect attacks in progress, or trigger their own emergency responses. This creates a massive gap between deploying a protocol and defending it at runtime.

The numbers are stark. In 2022 alone, $3.8 billion was stolen from DeFi protocols. Audits help, but they're a point-in-time snapshot — static tools catch roughly 26% of vulnerabilities, dynamic tools around 37%. The rest slip through. And once a contract is live, most teams rely on centralized monitoring: a server watching for anomalies, a human hitting the pause button. That's slow, fragile, and a single point of failure.

Drosera fills that gap. It's a decentralized network that continuously monitors smart contract state, detects anomalies in real time, and triggers automated responses — all without any single party in control. Think of it as a programmable immune system for on-chain protocols.

## 2. The Core Idea: Traps

Everything in Drosera revolves around **Traps**. A trap is a Solidity smart contract that defines what to watch and when to act. The name comes from the Venus Flytrap — a carnivorous plant from the Drosera genus that catches prey with snap traps.

Every trap implements two (or three) functions:

### `collect()` — The Eyes

```solidity
function collect() external view returns (bytes memory);
```

This function reads on-chain state and returns a snapshot. It runs every block. For example, a trap watching a lending protocol might read the total value locked, the collateralization ratio, and the oracle price. A trap watching a bridge might read the token balances held in the bridge contract.

The function must be `view` — it can only read, never write. It must never revert. If an external call fails (the target contract doesn't exist, the RPC is flaky), it returns a safe default like empty bytes. A reverting `collect()` breaks the entire monitoring loop.

### `shouldRespond()` — The Brain

```solidity
function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
```

This is where the analysis happens. Operators pass in an array of snapshots from recent blocks — `data[0]` is the most recent, `data[N-1]` is the oldest. The function decodes these snapshots, compares them, and decides: is something wrong?

The function must be `pure` — no reading storage, no external calls, no dependencies on `msg.sender` or `block.timestamp`. Given the same input bytes, it must always return the same result. This is critical because multiple independent operators need to arrive at the same conclusion.

If the answer is "yes, something is wrong," it returns `(true, responsePayload)` where the payload is ABI-encoded data to pass to the response contract. If everything is fine, it returns `(false, "")`.

### `shouldAlert()` — The Alternative

Some traps don't need an on-chain response. They just need to notify someone. `shouldAlert()` works identically to `shouldRespond()` but routes its output to off-chain alert channels (Slack, webhooks, email) instead of calling a response contract.

### What Makes a Good Trap

The best traps follow a **snapshot comparison** pattern. They don't look at a single moment in time — they look at how things have changed across multiple blocks. A balance dropping by 5% in one block might be normal. A balance dropping by 50% in one block, preceded by 5 blocks of unusual activity, probably isn't.

Strong signals combine multiple metrics: price deviation versus a time-weighted average, liquidity drops versus a rolling baseline, treasury concentration shifts correlated with governance activity. Single-threshold triggers ("alert if balance < X") tend to produce false positives. Multi-metric, time-series analysis produces meaningful signals.

## 3. The Operator Network

Traps are just code. They need someone to run them. That's what **operators** do.

An operator is a node in the Drosera network. It runs a shadow fork of the EVM — essentially a local copy of Ethereum state that it uses to execute trap bytecode off-chain. Every block, the operator:

1. Calls `collect()` on each trap it's opted into, producing a snapshot
2. Stores the snapshot in a rolling buffer (the last N blocks, configurable via `block_sample_size`)
3. Calls `shouldRespond()` with the buffered snapshots
4. If the result is `true`, signs the result and broadcasts it to other operators

Operators communicate via **LibP2P**, a peer-to-peer networking stack. They don't trust each other — they verify each other.

### Consensus via BLS Signatures

When an operator determines that `shouldRespond()` returns `true`, it doesn't immediately fire a response. Instead, it signs a **claim** — a data packet containing the block number and the trap result — using its BLS private key, and broadcasts it to the network.

Other operators independently run the same computation. If they agree, they co-sign the claim. Once a claim accumulates signatures from **2/3 of the operators** assigned to that trap, it becomes a valid **submission**.

The first operator to submit this 2/3-signed claim on-chain triggers the response. The Drosera contract on Ethereum verifies the aggregate BLS signature and, if valid, calls the trap's configured response function on the response contract.

This is modeled after Ethereum's own consensus mechanism. No single operator can trigger a false alarm. No minority coalition can manipulate the system. You need a supermajority to act.

### Verification via Zero-Knowledge Proofs

BLS consensus tells you that 2/3 of operators agree. But what if 2/3 of operators collude to lie? Drosera addresses this with **SNARK proofs**. If a submission's claims are proven incorrect via a zero-knowledge proof, every operator who signed it gets slashed — their stake is seized and they're ejected from the network.

This creates a strong economic disincentive against collusion. The cost of getting caught vastly outweighs the benefit of lying.

## 4. Response Mechanisms

When a trap fires and consensus is reached, the Drosera contract calls:

```
responseContract.responseFunction(payload)
```

The response contract is entirely up to the protocol developer. Common patterns include:

- **Emergency pause**: Halt all protocol operations (deposits, withdrawals, borrows)
- **Treasury freeze**: Lock token movements from the treasury
- **Governance escalation**: Trigger a timelock or multisig proposal
- **Collateral rebalancing**: Move assets to safer positions
- **Bridge halt**: Stop cross-chain transfers
- **Webhook/alert emission**: Notify off-chain systems (Slack, PagerDuty, The Graph)

The response contract should be access-controlled — only the Drosera contract (or a specific caller) should be able to invoke it. Optional protections include cooldown periods (don't fire twice in 20 blocks), multi-sig approval gates, and escalation tiers (warning → pause → full shutdown).

A critical design principle: **traps detect, responders act**. The trap never has side effects. The responder never has detection logic. Keeping them separated makes both easier to reason about, test, and audit.

## 5. Hidden Security Intents

Here's a subtle but important design choice: trap bytecode lives **off-chain**. The on-chain `TrapConfig` contract stores configuration (which response contract to call, how many operators are needed, cooldown periods), but the actual detection logic — what the trap is watching for — is never published on-chain.

This is a deliberate security feature. If an attacker could read the trap's source code on-chain, they'd know exactly which conditions trigger the emergency response. They could craft their exploit to avoid those conditions, or front-run the response transaction.

By keeping the logic off-chain and only publishing it to the operator network, Drosera creates an information asymmetry that favors defenders. Attackers are flying blind — they don't know what the tripwires are.

## 6. Tokenomics and Incentives

### The DRO Token

DRO is Drosera's native ERC20 token (with ERC1363 extensions for single-transaction approvals). It serves three purposes: paying operators, staking for security, and creating reward streams.

### Hydration Streams

A Hydration Stream is a flow of tokens directed at a specific trap. Anyone can create one — the protocol itself, a concerned community member, a DAO treasury. The stream distributes tokens to operators over time, split three ways:

| Channel | Share | Purpose |
|---|---|---|
| Passive rewards | 70% | Distributed to all opted-in operators proportionally, just for being online and running the trap |
| Active rewards | 20% | Accumulates in a bonus pool. When an incident is detected: 50% goes to the operator who submits the consensus claim, 50% is split among operators who co-signed |
| Staking rewards | 10% | Flows to the Harvester Pool, distributed to DRO stakers based on stake size and duration |

This creates a layered incentive structure. Operators earn a baseline for uptime (passive), a bonus for being fast and accurate during incidents (active), and token holders earn yield for securing the network (staking).

### Bloom Boost

Bloom Boost is ETH deposited on a trap to **prioritize emergency response transactions** during block building. When an incident is detected, the response transaction competes with other transactions for block inclusion. Bloom Boost effectively bribes block builders (proposers, searchers) to include the emergency transaction first.

This is a clever use of the MEV supply chain for defense rather than extraction. Instead of MEV extracting value from protocols, Bloom Boost channels it toward protecting them.

## 7. Slashing and Accountability

Operators face real economic consequences for misbehavior:

- **Incorrect attestation**: If an operator signs a claim that's provably wrong (verified via SNARK), they're slashed and ejected from the network
- **Inactivity** (planned): Operators who fail to sign any of the last X submissions face penalties. The network monitors peer-to-peer activity to detect offline nodes
- **Censorship** (planned): Operators who repeatedly exclude specific signers from their submissions can be penalized, unless the excluded signer is genuinely inactive

Future plans include integration with **restaking protocols** (like EigenLayer), allowing operators to put up additional economic security by restaking ETH or LSTs.

## 8. Developer Workflow

Building a Drosera trap follows a standard Foundry workflow:

### Setup

```bash
# Install dependencies
forge install

# Project structure
src/
  traps/          # Trap contracts (collect + shouldRespond)
  feeders/        # Optional feeder contracts (off-chain data bridge)
  responders/     # Response handler contracts
  interfaces/     # Shared interfaces
test/             # Foundry tests
drosera.toml      # Trap deployment configuration
foundry.toml      # Foundry build configuration
```

### Writing a Trap

A minimal trap looks like this:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

contract VaultMonitorTrap is ITrap {
    address constant VAULT = 0x...;
    uint256 constant DROP_THRESHOLD_BPS = 5000; // 50%

    function collect() external view override returns (bytes memory) {
        uint256 balance = IERC20(TOKEN).balanceOf(VAULT);
        return abi.encode(balance);
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2 || data[0].length == 0 || data[1].length == 0)
            return (false, "");

        uint256 current = abi.decode(data[0], (uint256));
        uint256 previous = abi.decode(data[1], (uint256));

        if (previous == 0) return (false, "");

        uint256 dropBps = ((previous - current) * 10000) / previous;
        if (dropBps > DROP_THRESHOLD_BPS) {
            return (true, abi.encode(current, previous, dropBps));
        }
        return (false, "");
    }
}
```

### Configuration

```toml
# drosera.toml
ethereum_rpc = "https://rpc.mevblocker.io"
eth_chain_id = 1
drosera_address = "0x..."

[traps.vault_monitor]
path = "out/VaultMonitorTrap.sol/VaultMonitorTrap.json"
response_contract = "0xResponderAddress"
response_function = "emergencyPause(bytes)"
block_sample_size = 10
cooldown_period_blocks = 20
min_number_of_operators = 3
max_number_of_operators = 10
private_trap = true
whitelist = []
```

### Testing

```bash
# Compile
forge build

# Run unit tests (use vm.createFork for historical block data)
forge test

# Validate target contracts exist
cast code 0xVaultAddress --rpc-url $ETH_RPC_URL

# Simulate trap execution against live state
drosera dryrun

# Never deploy without a successful dryrun
```

Tests typically fork mainnet at specific block numbers, collect snapshots across multiple blocks, and verify that `shouldRespond()` correctly identifies known incidents (or correctly ignores normal activity).

## 9. Real-World Case Studies

### Nomad Bridge ($190M, August 2022)

The Nomad bridge had a configuration vulnerability that allowed anyone to drain funds. The first attacker extracted 100 WBTC (~$2.3M). Once the method was public, hundreds of copycats repeated the same transaction — withdrawing ~202,440 USDC per transaction, over 200 times, across multiple blocks.

A Drosera trap monitoring bridge TVL would have detected the anomalous drain within the first few blocks. With a 2/3 operator consensus, it could have triggered an emergency pause, saving an estimated $42.4M in WBTC alone. The example implementation in this repo (`examples/bridges/nomad/`) demonstrates exactly this.

### Wormhole ($321M, February 2022)

An attacker exploited a signature verification flaw to mint 120,000 wETH on Solana, then bridged 93,750 wETH back to Ethereum for $254M. The Wormhole team offered a $10M bug bounty hoping the attacker would return funds.

With Drosera, those funds could have paid operators to detect and respond to the exploit in real time. A trap monitoring minting events against expected parameters would have caught the unauthorized mint and triggered a bridge halt before the ETH-side redemption completed.

### Euler Finance ($197M, March 2023)

A flash loan attack exploited Euler's donation and liquidation mechanics across multiple transactions. The example in this repo (`examples/lending-protocols/euler/`) reconstructs the attack and shows how a trap monitoring protocol state transitions (collateral ratios, flash loan activity, liquidation patterns) would have detected it.

## 10. Advanced Patterns

Beyond simple threshold monitoring, the examples in this repo demonstrate sophisticated patterns:

- **Time-series analysis**: TWAP oracle manipulation detection across 100-block windows (`examples/oracles/twap/`)
- **Multi-source verification**: Cross-DEX liquidity tracking to distinguish migrations from rug pulls (`examples/MultiDexLiquidityTrap/`)
- **Behavioral scoring**: Governance manipulation detection with severity scoring based on proposer age, funding source, and vote timing (`examples/InsiderGovernanceManipulationTrap/`)
- **Event filtering**: Monitoring specific ERC-20 Transfer events using Drosera's EventFilter and EventLog abstractions (`trap-foundry-template/src/TransferEventTrap.sol`)
- **Feeder pattern**: Off-chain analytics systems that write computed snapshots to a minimal on-chain feeder contract, which the trap then reads. This allows complex analysis (ML models, cross-chain data, mempool scanning) to feed into simple, deterministic trap logic
- **Progressive escalation**: Warning → pause → full shutdown tiers based on signal severity and persistence

## 11. Architecture Summary

```
                    ┌─────────────────────────────────────────────────┐
                    │               DROSERA NETWORK                   │
                    │                                                 │
  Every block:      │  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
  ┌──────────┐      │  │ Operator A│  │ Operator B│  │ Operator C│  │
  │ Ethereum │──────│──│           │  │           │  │           │  │
  │   State  │      │  │ collect() │  │ collect() │  │ collect() │  │
  └──────────┘      │  │ analyze() │  │ analyze() │  │ analyze() │  │
                    │  │ sign(BLS) │  │ sign(BLS) │  │ sign(BLS) │  │
                    │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  │
                    │        │    LibP2P     │              │        │
                    │        └───────┬───────┘              │        │
                    │                │  2/3 consensus?      │        │
                    │                ▼                       │        │
                    │        ┌──────────────┐               │        │
                    │        │  Aggregate   │◄──────────────┘        │
                    │        │  BLS Sigs    │                        │
                    │        └──────┬───────┘                        │
                    └───────────────┼────────────────────────────────┘
                                    │
                                    ▼ submit on-chain
                    ┌──────────────────────────────────┐
                    │     Drosera Contract (Ethereum)   │
                    │  - verify aggregate BLS signature │
                    │  - call response contract         │
                    └───────────────┬──────────────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────────┐
                    │     Response Contract             │
                    │  - pause protocol                 │
                    │  - freeze treasury                │
                    │  - emit alert                     │
                    │  - escalate to governance         │
                    └──────────────────────────────────┘
```

## 12. Key Design Principles

1. **Traps detect, responders act.** Never mix detection logic with side effects.
2. **Determinism is non-negotiable.** Same input, same output, every time, on every node.
3. **Never revert.** A failing trap is worse than no trap. Handle errors gracefully.
4. **Stateless over stateful.** Traps compare snapshots, they don't accumulate state.
5. **Multi-signal over single-threshold.** Combine metrics and time-series for robust detection.
6. **Defense in depth.** Drosera complements audits and formal verification — it doesn't replace them.
7. **Information asymmetry favors defenders.** Keep trap logic off-chain so attackers can't study it.
8. **Economic alignment.** Operators are paid for honesty and slashed for lying. The math has to work.
