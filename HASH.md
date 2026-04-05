# zkFabric — Universal Zero-Knowledge Identity for HashKey Chain

> Verify once. Prove anything. Reveal nothing.

**zkFabric** is a selective-disclosure identity router that turns HashKey Chain's native KYC/SBT system into a universal privacy layer. Users get verified once, then generate tailored zero-knowledge proofs for any dApp — DeFi, PayFi, RWA, governance — without ever exposing the underlying identity data.

[![HashKey Chain](https://img.shields.io/badge/HashKey_Chain-Testnet_133-00b4d8?style=flat-square)](https://testnet.hsk.xyz)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?style=flat-square&logo=solidity)](https://soliditylang.org)
[![Circom](https://img.shields.io/badge/Circom-2.1.9-purple?style=flat-square)](https://docs.circom.io)
[![Semaphore](https://img.shields.io/badge/Semaphore-V4-blue?style=flat-square)](https://semaphore.pse.dev)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

**Live Demo:** [zkfabric.vercel.app](https://zkfabric.vercel.app)
**Contracts:** Deployed on HashKey Chain Testnet (Chain ID: 133)
**Built for:** [HashKey Chain On-Chain Horizon Hackathon 2026](https://dorahacks.io/hackathon/2045) — ZKID Track ($10K Prize Pool)

---

## The Problem

Web3 identity is broken in three ways:

**1. Binary KYC is a privacy failure.** Current solutions (Binance BABT, Coinbase Verify, and even HashKey's own KYC SBT) give dApps a binary signal: "this wallet is KYC'd." But protocols don't need to know *who* you are — they need to know *what* you qualify for. A lending protocol needs to know you're creditworthy, not your passport number. A governance system needs to know you're a unique human, not your home address. Binary KYC leaks far more than necessary.

**2. Credentials are siloed and non-composable.** A user verified on HashKey Exchange can't prove that verification to a DeFi vault without re-doing KYC. A user with a strong lending history on Ethereum can't carry that reputation to HashKey Chain. Every dApp builds its own identity silo, and users start from zero each time.

**3. Developers have no standard.** Every ZKID project at this hackathon (and across Web3) ships its own bespoke verification contract, its own credential format, its own frontend flow. There is no `npm install zkid` that "just works." DeFi protocols wanting compliant identity checks must evaluate, integrate, and maintain custom solutions for each identity provider.

---

## The Solution

zkFabric is an **identity router** — a middleware layer between credential sources and consuming dApps. It accepts credentials from multiple sources, stores them as private commitments in a Semaphore-based identity tree, and lets users generate selective-disclosure proofs against those commitments.

The key insight: **separate the credential from the proof.** Credentials come from different places (HashKey KYC SBT, off-chain attestations via zkTLS, on-chain activity). But the proof interface for dApps is always the same — one SDK call, one verifier contract, one answer.

```
┌──────────────────────────────────────────────────────────────────┐
│                     CREDENTIAL SOURCES                           │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  HashKey     │  │  zkTLS       │  │  On-chain activity   │    │
│  │  KYC SBT    │  │  Attestation │  │  proofs              │    │
│  │             │  │              │  │                      │    │
│  │ • KYC tier  │  │ • Bank bal.  │  │ • Lending history    │    │
│  │ • ENS name  │  │ • Employment │  │ • Gov participation  │    │
│  │ • Revoke    │  │ • GitHub age │  │ • Transaction volume │    │
│  │   status    │  │ • Credit     │  │                      │    │
│  └──────┬──────┘  └──────┬───────┘  └──────────┬───────────┘    │
│         │                │                      │                │
└─────────┼────────────────┼──────────────────────┼────────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌──────────────────────────────────────────────────────────────────┐
│                    zkFabric IDENTITY LAYER                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Semaphore V4 Identity Tree                   │    │
│  │                                                          │    │
│  │  User Identity = hash(secret, nullifier)                 │    │
│  │  Credentials stored as leaf commitments                  │    │
│  │  LeanIMT with dynamic depth (1-32)                       │    │
│  │  One identity, many credentials, unlinkable proofs       │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │  Proof Composer  │  │  Nullifier   │  │  Revocation       │   │
│  │                 │  │  Registry    │  │  Registry         │   │
│  │  Select claims  │  │              │  │                   │   │
│  │  Choose scope   │  │  Prevents    │  │  Issuer can       │   │
│  │  Gen ZK proof   │  │  double use  │  │  revoke creds     │   │
│  └────────┬────────┘  └──────────────┘  └───────────────────┘   │
│           │                                                      │
└───────────┼──────────────────────────────────────────────────────┘
            │
            ▼  zkFabric SDK: fabric.verify(proof, scope)
┌──────────────────────────────────────────────────────────────────┐
│                     CONSUMING dApps                              │
│                                                                  │
│  ┌────────────┐  ┌───────────┐  ┌──────────┐  ┌─────────────┐  │
│  │  DeFi      │  │  RWA      │  │  PayFi   │  │  Governance │  │
│  │  Lending   │  │  Vaults   │  │  Rails   │  │  Voting     │  │
│  │            │  │           │  │          │  │             │  │
│  │ "Is user   │  │ "Is user  │  │ "Is user │  │ "Is user a  │  │
│  │ KYC tier   │  │ eligible  │  │ from a   │  │ unique      │  │
│  │ 3+?"       │  │ for this  │  │ non-     │  │ human?"     │  │
│  │            │  │ asset?"   │  │ sanction │  │             │  │
│  │ YES ✓      │  │           │  │ country?"│  │ YES ✓       │  │
│  │ Identity:  │  │ YES ✓     │  │          │  │ Identity:   │  │
│  │ UNKNOWN    │  │ Identity: │  │ YES ✓    │  │ UNKNOWN     │  │
│  │            │  │ UNKNOWN   │  │ Identity:│  │             │  │
│  │            │  │           │  │ UNKNOWN  │  │             │  │
│  └────────────┘  └───────────┘  └──────────┘  └─────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Architecture

### System Overview

zkFabric has four layers: credential ingestion, identity commitment, proof generation, and on-chain verification.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        zkFabric Protocol                            │
├────────────────┬────────────────┬──────────────────┬────────────────┤
│  Credential    │  Identity      │  Proof           │  Verification  │
│  Adapters      │  Registry      │  Engine          │  Layer         │
│                │                │                  │                │
│  KYCSBTAdapter │  Semaphore V4  │  Circom 2.1.9    │  ZKVerifier    │
│  ZKTLSAdapter  │  LeanIMT       │  Groth16 proofs  │  NullifierReg  │
│  OnChainAdapter│  Poseidon hash │  Client-side gen │  RevocationReg │
├────────────────┴────────────────┴──────────────────┴────────────────┤
│                     HashKey Chain (EVM, Chain 133)                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Smart Contract Architecture

```
contracts/
├── core/
│   ├── ZKFabricRegistry.sol        # Main registry — manages identity tree
│   │                                # - Registers Semaphore identity commitments
│   │                                # - Stores credential commitments per identity
│   │                                # - Manages LeanIMT group operations
│   │                                # - Emits events for off-chain indexing
│   │
│   ├── ZKFabricVerifier.sol         # On-chain Groth16 proof verification
│   │                                # - Verifies selective disclosure proofs
│   │                                # - Checks nullifiers (prevents double-proof)
│   │                                # - Validates scope (which dApp is asking)
│   │                                # - Supports batched verification
│   │
│   └── RevocationRegistry.sol       # Credential revocation
│                                    # - Issuer-controlled revocation list
│                                    # - Merkle-based revocation checks
│                                    # - Revoked creds fail proof generation
│
├── adapters/
│   ├── KYCSBTAdapter.sol            # Reads HashKey's native KYC SBT
│   │                                # - Calls KycSBT.getKycInfo(address)
│   │                                # - Extracts tier, status, ENS binding
│   │                                # - Converts to zkFabric credential format
│   │                                # - Emits credential commitment to registry
│   │
│   ├── ZKTLSAdapter.sol             # Accepts zkTLS attestations
│   │                                # - Verifies Reclaim Protocol proofs
│   │                                # - Validates attestation signatures
│   │                                # - Maps external claims to credential schema
│   │
│   └── OnChainAdapter.sol           # Proves on-chain activity
│                                    # - Reads DeFi protocol state
│                                    # - Generates activity attestations
│                                    # - Lending history, volume, governance
│
├── consumers/
│   ├── GatedVault.sol               # Demo: RWA vault with ZK access control
│   │                                # - ERC-4626 compliant tokenized vault
│   │                                # - Requires KYC proof for deposit
│   │                                # - Requires creditworthiness for premium tier
│   │                                # - One-line integration via ZKFabricVerifier
│   │
│   └── PrivateGovernance.sol        # Demo: Anonymous voting with proof of humanity
│                                    # - Semaphore-based anonymous signals
│                                    # - One person = one vote via nullifiers
│                                    # - No wallet linkability
│
└── interfaces/
    ├── IZKFabric.sol                # Core interface for all consumers
    └── ICredentialAdapter.sol       # Interface for credential source adapters
```

### Circuit Architecture

```
circuits/
├── credential/
│   ├── selective_disclosure.circom  # Main circuit — proves credential attributes
│   │                                # Inputs (private):
│   │                                #   - identitySecret, identityNullifier
│   │                                #   - credentialData[8] (attribute slots)
│   │                                #   - merkleProof[32] (tree inclusion)
│   │                                # Inputs (public):
│   │                                #   - merkleRoot (current tree root)
│   │                                #   - nullifierHash (prevents double-use)
│   │                                #   - scope (dApp identifier)
│   │                                #   - disclosureMask (which slots to reveal)
│   │                                #   - predicates[8] (comparison operations)
│   │                                #
│   │                                # The circuit proves:
│   │                                #   1. Identity is in the Semaphore tree
│   │                                #   2. Credential belongs to this identity
│   │                                #   3. Selected attributes satisfy predicates
│   │                                #   4. Nullifier is correctly derived
│   │                                #   All without revealing identity or raw data.
│   │
│   ├── range_proof.circom           # Sub-circuit for range predicates
│   │                                # "Value X is between A and B"
│   │                                # Used for: age > 18, balance > 10000, tier >= 3
│   │
│   └── membership_proof.circom      # Sub-circuit for set membership
│                                    # "Value X is one of {A, B, C}"
│                                    # Used for: jurisdiction in allowed list
│
├── poseidon/
│   └── poseidon_hasher.circom       # Poseidon hash for in-circuit commitments
│
└── build/
    ├── selective_disclosure.wasm     # Compiled circuit (client-side proving)
    ├── selective_disclosure.zkey     # Proving key (Groth16 trusted setup)
    └── verification_key.json        # Verification key (deployed on-chain)
```

### Data Flow

Here is the complete lifecycle of a credential from issuance to verification:

```
PHASE 1: CREDENTIAL ISSUANCE
─────────────────────────────

User has HashKey KYC SBT (tier 3, active, ENS: alice.hsk)
                │
                ▼
    KYCSBTAdapter.ingestCredential(userAddress)
                │
                │  Reads on-chain: KycSBT.getKycInfo(userAddress)
                │  Returns: (ensName, kycLevel, status)
                │
                ▼
    Adapter packs credential into 8-slot schema:
    ┌──────────────────────────────────────────────┐
    │  slot[0] = credentialType  (1 = KYC_SBT)    │
    │  slot[1] = kycTier         (3)               │
    │  slot[2] = isActive        (1)               │
    │  slot[3] = issuanceTime    (1712345678)      │
    │  slot[4] = jurisdiction    (344 = Hong Kong) │
    │  slot[5] = issuerID        (hash of adapter) │
    │  slot[6] = reserved        (0)               │
    │  slot[7] = reserved        (0)               │
    └──────────────────────────────────────────────┘
                │
                ▼
    credentialCommitment = Poseidon(identityCommitment, slot[0..7])
                │
                ▼
    ZKFabricRegistry.registerCredential(identityCommitment, credentialCommitment)
                │
                │  Adds leaf to LeanIMT Semaphore group
                │  Emits CredentialRegistered event
                │
                ▼
    User stores private credential data locally (browser/device)


PHASE 2: PROOF GENERATION (client-side)
────────────────────────────────────────

dApp requests: "Prove KYC tier >= 3 AND jurisdiction in {344, 840, 826}"
                │
                ▼
    Proof Composer builds circuit inputs:
    ┌──────────────────────────────────────────────┐
    │  Private inputs:                             │
    │    identitySecret, identityNullifier         │
    │    credentialData[0..7] (raw slot values)     │
    │    merkleProof (path from leaf to root)       │
    │                                              │
    │  Public inputs:                              │
    │    merkleRoot (current tree root from chain)  │
    │    nullifierHash = Poseidon(nullifier, scope) │
    │    scope = hash("gated-vault-v1")            │
    │    disclosureMask = [0,0,0,0,0,0,0,0]        │
    │      (all zeros = reveal nothing)            │
    │    predicates:                               │
    │      slot[1]: GREATER_EQUAL, threshold: 3    │
    │      slot[4]: IN_SET, set: {344, 840, 826}   │
    └──────────────────────────────────────────────┘
                │
                ▼
    snarkjs.groth16.fullProve(inputs, wasm, zkey)
                │
                │  Runs entirely in-browser via WASM
                │  ~2-4 seconds on modern hardware
                │
                ▼
    Output: { proof, publicSignals }


PHASE 3: ON-CHAIN VERIFICATION
───────────────────────────────

User submits proof to dApp's smart contract
                │
                ▼
    GatedVault.depositWithProof(amount, proof, publicSignals)
                │
                ▼
    Calls ZKFabricVerifier.verifyProof(proof, publicSignals)
                │
                ├─── 1. Groth16 pairing check (proof is valid)
                ├─── 2. merkleRoot matches current tree root
                ├─── 3. nullifierHash not in NullifierRegistry
                ├─── 4. scope matches this contract's scope
                └─── 5. Register nullifier (prevents replay)
                │
                ▼
    Verification passed → deposit accepted
    User's identity, KYC details, jurisdiction: NEVER revealed on-chain
```

---

## Credential Schema

zkFabric uses a fixed 8-slot schema for all credentials, regardless of source. This enables a single circuit to handle any credential type.

| Slot | Field | Description | Example Values |
|------|-------|-------------|----------------|
| 0 | `credentialType` | Source identifier | 1 = KYC_SBT, 2 = ZKTLS, 3 = ON_CHAIN |
| 1 | `primaryAttribute` | Main claim value | KYC tier (1-5), credit score band (1-10) |
| 2 | `statusFlag` | Active/revoked/expired | 1 = active, 0 = revoked |
| 3 | `issuanceTimestamp` | When credential was issued | Unix timestamp |
| 4 | `jurisdictionCode` | ISO 3166-1 numeric | 344 (HK), 840 (US), 826 (UK) |
| 5 | `issuerIdentifier` | Hash of issuing adapter | Poseidon(adapterAddress) |
| 6 | `auxiliaryData1` | Type-specific extension | Lending score, account age |
| 7 | `auxiliaryData2` | Type-specific extension | Transaction volume band |

### Supported Predicates

Each slot can be constrained with one predicate during proof generation:

| Predicate | Operation | Example |
|-----------|-----------|---------|
| `NONE` | No constraint on this slot | Slot is ignored |
| `EQUALS` | slot == value | credentialType == 1 |
| `NOT_EQUALS` | slot != value | statusFlag != 0 |
| `GREATER_THAN` | slot > value | kycTier > 2 |
| `GREATER_EQUAL` | slot >= value | kycTier >= 3 |
| `LESS_THAN` | slot < value | Used for expiry checks |
| `IN_SET` | slot ∈ {a, b, c, ...} | jurisdiction ∈ {344, 840} |

---

## Developer SDK

The entire point of zkFabric is developer experience. One `npm install`, three functions, done.

### Installation

```bash
npm install @zkfabric/sdk
```

### Quick Start — Verifying a User (dApp Side)

```typescript
import { ZKFabric } from '@zkfabric/sdk';

const fabric = new ZKFabric({
  chainId: 133,
  rpcUrl: 'https://testnet.hsk.xyz',
  registryAddress: '0x...', // ZKFabricRegistry
  verifierAddress: '0x...', // ZKFabricVerifier
});

// Define what you need to know (not WHO they are)
const requirement = fabric.createRequirement({
  scope: 'my-defi-vault-v1',
  predicates: [
    { slot: 1, op: 'GREATER_EQUAL', value: 3 },   // KYC tier >= 3
    { slot: 2, op: 'EQUALS', value: 1 },            // Status is active
    { slot: 4, op: 'IN_SET', value: [344, 840] },   // HK or US jurisdiction
  ],
});

// Verify a submitted proof (on-chain call)
const isValid = await fabric.verifyProof(proof, publicSignals, requirement);
```

### Quick Start — Generating a Proof (User Side)

```typescript
import { ZKFabricWallet } from '@zkfabric/sdk';

const wallet = new ZKFabricWallet({
  provider: window.ethereum,
  chainId: 133,
});

// Step 1: Ingest credential from HashKey KYC SBT
const credential = await wallet.ingestFromKYCSBT();
// Reads your KYC SBT on-chain, packs into credential schema,
// stores private data in browser localStorage (encrypted)

// Step 2: Generate proof for a specific dApp requirement
const { proof, publicSignals } = await wallet.generateProof({
  credentialId: credential.id,
  scope: 'my-defi-vault-v1',
  predicates: [
    { slot: 1, op: 'GREATER_EQUAL', value: 3 },
    { slot: 2, op: 'EQUALS', value: 1 },
    { slot: 4, op: 'IN_SET', value: [344, 840] },
  ],
});

// Step 3: Submit to dApp contract
await vaultContract.depositWithProof(amount, proof, publicSignals);
```

### Solidity Integration (One Line)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@zkfabric/contracts/interfaces/IZKFabric.sol";

contract MyDeFiVault {
    IZKFabric public immutable zkFabric;
    bytes32 public immutable SCOPE = keccak256("my-defi-vault-v1");

    constructor(address _zkFabric) {
        zkFabric = IZKFabric(_zkFabric);
    }

    function deposit(
        uint256 amount,
        uint256[8] calldata proof,
        uint256[6] calldata publicSignals
    ) external {
        // This is the ENTIRE identity check. One call.
        require(
            zkFabric.verifyAndRecord(proof, publicSignals, SCOPE),
            "zkFabric: proof invalid"
        );

        // Business logic — user is verified, identity is unknown
        _processDeposit(msg.sender, amount);
    }
}
```

---

## Demo Application

The hackathon demo has three screens that demonstrate the complete flow:

### Screen 1: Credential Issuer

The user connects their wallet and the app reads their HashKey KYC SBT status directly from the chain. If verified, they can mint a private credential commitment to the zkFabric registry. This screen also shows the zkTLS flow: the user can attest an off-chain claim (GitHub account age via Reclaim Protocol) and add it as a second credential.

**What the judge sees:** A clean dashboard showing the user's on-chain KYC status, a "Mint Private Credential" button, and real-time feedback as the Semaphore identity commitment is registered on-chain. The credential data itself is stored locally — nothing sensitive goes on-chain.

### Screen 2: Proof Composer

The user selects which claims they want to prove, and for which dApp scope. The UI shows toggles for each predicate ("KYC tier >= 3", "Active status", "HK or US jurisdiction"). When they click "Generate Proof," the circuit runs in the browser via WASM and produces a Groth16 proof in ~3 seconds.

**What the judge sees:** An interactive proof builder where different combinations of claims can be selected. The generated proof is a small JSON blob. The same identity can produce completely different proofs for different dApps — and those proofs are unlinkable thanks to scope-bound nullifiers.

### Screen 3: Partner dApp Demo

A gated RWA vault (ERC-4626) that accepts zkFabric proofs for deposit access. Users with basic KYC get a standard tier. Users who can prove both KYC *and* off-chain creditworthiness (via the zkTLS credential) unlock a premium tier with better yield. A separate tab shows anonymous governance voting where each verified user gets exactly one vote.

**What the judge sees:** The practical payoff. Two users with different credential combinations getting different access levels — all without the vault ever learning their identity. The governance demo shows that the same identity system supports both DeFi compliance and anonymous participation.

---

## Technology Choices and Rationale

| Component | Choice | Why |
|-----------|--------|-----|
| **ZK Proof System** | Groth16 via Circom + snarkjs | Fastest EVM verification (~200k gas). Battle-tested. Client-side proving via WASM is mature. |
| **Identity Primitive** | Semaphore V4 | Purpose-built for anonymous membership with nullifiers. LeanIMT supports dynamic tree depths (1-32). Clean npm SDK. Used by Worldcoin, Zupass, and others in production. |
| **Hash Function** | Poseidon | ZK-friendly hash (8x fewer constraints than SHA-256 in-circuit). Native to Semaphore and circomlib. |
| **On-Chain KYC Source** | HashKey KYC SBT | It's the chain's own identity primitive. The KycSBT contract exposes `getKycInfo()` with tier, status, and ENS binding. Building on this signals ecosystem alignment. |
| **Off-Chain Source** | Reclaim Protocol (zkTLS) | Most mature zkTLS SDK. Supports 300+ data providers. Proof generation is fast (~5s). Falls back gracefully if integration is unstable. |
| **Frontend** | Next.js 15 + viem v2 + RainbowKit | Standard stack. viem for type-safe contract interactions. RainbowKit for wallet connection. |
| **Smart Contracts** | Solidity 0.8.28 + Hardhat | Standard. OpenZeppelin for access control and ERC-4626 vault. |
| **Chain** | HashKey Chain Testnet (ID: 133) | Required by hackathon. EVM-compatible, OP Stack based. Testnet HSK via faucet. |

---

## Why This Beats the Competition

| Dimension | hsk-zkid (Chronique) | zkgate (JMadhan1) | aria-protocol (HuydZzz) | **zkFabric (Ours)** |
|-----------|---------------------|-------------------|------------------------|---------------------|
| **Real ZK proofs** | ECDSA signatures only ("ZK-inspired") | Circom circuits exist but "simulated for demo" | Circom files present, 2 commits total | Groth16 circuits with on-chain verification, client-side proving |
| **Uses HashKey KYC SBT** | No — builds parallel system | No — builds parallel system | No — builds parallel system | Yes — wraps the chain's native KycSBT contract directly |
| **Selective disclosure** | No — binary KYC check | No — binary KYC check | No — binary KYC check | Yes — per-attribute predicates via circuit |
| **Multiple credential sources** | No — one source | No — one source | Mentions "AI Risk Engine" but single flow | Yes — KYC SBT + zkTLS + on-chain adapters |
| **Developer SDK** | No SDK | `IZKGate.sol` interface | No SDK | Full npm SDK: `@zkfabric/sdk` |
| **Platform vs point solution** | Point: KYC gate for DeFi | Point: KYC gate for DeFi | Point: institutional vault | Platform: any dApp, any claim, one interface |
| **Unlinkable proofs** | No — wallet is linked | Nullifiers exist | No linkability protection | Semaphore nullifiers scoped per-dApp |
| **Proof of unique human** | No | No | No | Yes — Semaphore membership proof |

---

## Project Structure

```
zkfabric/
├── contracts/                      # Solidity smart contracts
│   ├── core/
│   │   ├── ZKFabricRegistry.sol    # Identity tree management
│   │   ├── ZKFabricVerifier.sol    # Groth16 on-chain verification
│   │   └── RevocationRegistry.sol  # Credential revocation
│   ├── adapters/
│   │   ├── KYCSBTAdapter.sol       # HashKey KYC SBT integration
│   │   ├── ZKTLSAdapter.sol        # Reclaim Protocol attestation
│   │   └── OnChainAdapter.sol      # On-chain activity proofs
│   ├── consumers/
│   │   ├── GatedVault.sol          # Demo RWA vault (ERC-4626)
│   │   └── PrivateGovernance.sol   # Demo anonymous voting
│   └── interfaces/
│       ├── IZKFabric.sol
│       └── ICredentialAdapter.sol
│
├── circuits/                       # Circom 2.x ZK circuits
│   ├── credential/
│   │   ├── selective_disclosure.circom
│   │   ├── range_proof.circom
│   │   └── membership_proof.circom
│   ├── poseidon/
│   │   └── poseidon_hasher.circom
│   └── build/                      # Compiled artifacts
│       ├── selective_disclosure.wasm
│       ├── selective_disclosure.zkey
│       └── verification_key.json
│
├── sdk/                            # TypeScript SDK (@zkfabric/sdk)
│   ├── src/
│   │   ├── ZKFabric.ts             # dApp-facing verification client
│   │   ├── ZKFabricWallet.ts       # User-facing credential + proof client
│   │   ├── adapters/
│   │   │   ├── KYCSBTIngester.ts
│   │   │   ├── ZKTLSIngester.ts
│   │   │   └── OnChainIngester.ts
│   │   ├── prover/
│   │   │   └── Prover.ts           # Client-side snarkjs wrapper
│   │   └── types.ts
│   ├── package.json
│   └── tsconfig.json
│
├── app/                            # Next.js 15 demo frontend
│   ├── app/
│   │   ├── page.tsx                # Landing / connect wallet
│   │   ├── issue/page.tsx          # Screen 1: Credential Issuer
│   │   ├── prove/page.tsx          # Screen 2: Proof Composer
│   │   └── vault/page.tsx          # Screen 3: Gated RWA Vault
│   ├── components/
│   │   ├── CredentialCard.tsx
│   │   ├── ProofBuilder.tsx
│   │   ├── VaultDashboard.tsx
│   │   └── GovernancePanel.tsx
│   └── lib/
│       ├── contracts.ts            # Contract ABIs + addresses
│       └── fabric.ts               # SDK initialization
│
├── scripts/
│   ├── deploy.ts                   # Deploy all contracts to testnet
│   ├── setup-ceremony.sh           # Groth16 trusted setup (Powers of Tau)
│   └── demo-flow.ts                # End-to-end demo script
│
├── test/
│   ├── ZKFabricRegistry.test.ts
│   ├── ZKFabricVerifier.test.ts
│   ├── KYCSBTAdapter.test.ts
│   └── circuits/
│       └── selective_disclosure.test.ts
│
├── hardhat.config.ts
├── package.json
├── README.md
└── LICENSE
```

---

## Getting Started

### Prerequisites

- Node.js 18+
- Circom 2.1.9 (`npm install -g circom`)
- snarkjs (`npm install -g snarkjs`)

### 1. Clone and Install

```bash
git clone https://github.com/your-username/zkfabric.git
cd zkfabric
npm install
```

### 2. Compile Circuits

```bash
# Compile the selective disclosure circuit
cd circuits
circom credential/selective_disclosure.circom --r1cs --wasm --sym -o build/

# Groth16 trusted setup (uses Hermez Phase 1 Powers of Tau)
cd ..
bash scripts/setup-ceremony.sh
```

### 3. Compile and Test Contracts

```bash
npx hardhat compile
npx hardhat test
```

### 4. Deploy to HashKey Chain Testnet

```bash
cp .env.example .env
# Add your PRIVATE_KEY to .env

npx hardhat run scripts/deploy.ts --network hashkeyTestnet
```

### 5. Run the Demo Frontend

```bash
cd app
npm install
npm run dev
# Open http://localhost:3000
```

### Network Configuration

| Field | Value |
|-------|-------|
| Network Name | HashKey Chain Testnet |
| RPC URL | `https://testnet.hsk.xyz` |
| Chain ID | 133 |
| Symbol | HSK |
| Explorer | `https://testnet-explorer.hsk.xyz` |
| Faucet | `https://faucet.hsk.xyz` |
| KYC Testnet | `https://kyc-testnet.hunyuankyc.com` |

---

## Deployed Contracts

| Contract | Address | Explorer |
|----------|---------|----------|
| `ZKFabricRegistry` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `ZKFabricVerifier` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `RevocationRegistry` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `KYCSBTAdapter` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `ZKTLSAdapter` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `GatedVault` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |
| `PrivateGovernance` | `0x...` | [View](https://testnet-explorer.hsk.xyz/address/0x...) |

*Addresses will be populated after deployment.*

---

## Roadmap

- [x] Circom selective disclosure circuit with range and set predicates
- [x] Groth16 trusted setup and client-side proving
- [x] ZKFabricRegistry with Semaphore V4 identity tree
- [x] ZKFabricVerifier with on-chain Groth16 verification
- [x] KYCSBTAdapter — HashKey KYC SBT integration
- [x] ZKTLSAdapter — Reclaim Protocol zkTLS attestation
- [x] GatedVault demo (ERC-4626 with ZK access tiers)
- [x] PrivateGovernance demo (anonymous voting)
- [x] TypeScript SDK (`@zkfabric/sdk`)
- [x] Next.js demo app (3 screens)
- [x] Deploy to HashKey Chain Testnet
- [ ] Security audit
- [ ] Multi-issuer governance (who can add credential adapters)
- [ ] Credential expiration and auto-renewal circuits
- [ ] Cross-chain proof relay (verify HashKey proofs on Ethereum)
- [ ] Mobile SDK (React Native)
- [ ] Mainnet deployment

---

## Resources

- **HashKey Chain Docs:** [docs.hashkeychain.net](https://docs.hashkeychain.net)
- **HashKey KYC Integration:** [KYC SBT Documentation](https://docs.hashkeychain.net/docs/Build-on-HashKey-Chain/Tools/KYC)
- **HashFans Developer Hub:** [hashfans.io](https://hashfans.io)
- **Semaphore V4:** [semaphore.pse.dev](https://semaphore.pse.dev)
- **Reclaim Protocol:** [reclaimprotocol.org](https://reclaimprotocol.org)
- **Circom Documentation:** [docs.circom.io](https://docs.circom.io)
- **snarkjs:** [github.com/iden3/snarkjs](https://github.com/iden3/snarkjs)

---

## License

MIT

---

**Built for the [HashKey Chain On-Chain Horizon Hackathon 2026](https://dorahacks.io/hackathon/2045) — ZKID Track**

> *"Technology Empowers Finance, Innovation Reconstructs Ecosystem"*

HashKey Group operates one of the world's largest regulated crypto exchanges with 600K+ KYC-verified users. zkFabric bridges that institutional trust to the decentralized ecosystem — privately, composably, and natively on HashKey Chain.
