# Drosera Incubator — 1:1 Meeting Prep

## What This Meeting Is

This is a 1:1 with the Drosera team (Bjorn Agnesi) as part of the Incubator onboarding. They want to understand your strengths, interests, and where you'd be best positioned to contribute. They're looking for builders and educators who can help projects discover Drosera and apply it to real-world needs.

This is not a quiz. It's a conversation. But being sharp on the fundamentals and having a clear picture of where you want to contribute will make a strong impression.

---

## Part 1: Key Facts to Have Ready

### What Drosera Is (30-second pitch)

Drosera is a decentralized security automation layer for Ethereum. It lets protocols define monitoring logic ("traps") that operators run off-chain every block. When a trap detects an anomaly, operators reach consensus via BLS signatures and trigger an on-chain response — like pausing a protocol or freezing a treasury. Trap bytecode stays off-chain so attackers can't study the detection logic. The whole system is trustless, verified by zero-knowledge proofs, and economically secured through staking and slashing.

### The Problem It Solves

- $3.8B stolen from DeFi in 2022
- Audits are point-in-time — static tools catch ~26% of bugs, dynamic ~37%
- Once deployed, most protocols rely on centralized monitoring (one server, one human, one button)
- Smart contracts are reactive — they can't watch their own state or trigger their own emergency responses
- Drosera fills the gap between "deployed" and "defended"

### Core Components

| Component | What It Does |
|---|---|
| **Trap** | Solidity contract with `collect()` (read state every block) and `shouldRespond()` / `shouldAlert()` (analyze snapshots, decide if something is wrong) |
| **Operator** | Node that runs traps off-chain on a shadow EVM fork, signs results with BLS, broadcasts to peers |
| **Responder** | On-chain contract that executes the emergency action (pause, freeze, escalate) |
| **Feeder** | Optional on-chain bridge for off-chain analytics data |
| **TrapConfig** | On-chain config (response contract, operator count, cooldown) — but trap logic stays off-chain |
| **Hydration Stream** | Token reward stream directed at a specific trap, paying operators over time |
| **Bloom Boost** | ETH deposited to prioritize emergency response transactions via block builders |

### How Consensus Works

1. Operator runs `shouldRespond()` → gets `true`
2. Signs a claim (block number + result) with BLS private key
3. Broadcasts to peers via LibP2P
4. Other operators independently verify and co-sign
5. At 2/3 signatures → valid submission
6. First operator to submit on-chain triggers the response and gets a bonus reward
7. Incorrect claims can be disproven via SNARK proofs → signers slashed and ejected

### Tokenomics (DRO)

- ERC20 + ERC1363 token
- Hydration Streams split rewards: 70% passive (uptime), 20% active (incident response), 10% staking (Harvester Pool)
- Active reward bonus: 50% to the submitter, 50% split among co-signers
- Staking in the Harvester gives yield from all traps' staking share
- Future: restaking integration (EigenLayer-style)

### Trap Design Rules

- `collect()` must be `external view`, must never revert, returns safe defaults on failure
- `shouldRespond()` must be `external pure`, fully deterministic
- No storage writes, events, external state changes, `msg.sender`, randomness
- Stateless — use constants, hardcoded addresses, snapshot comparisons
- Use basis points for thresholds, compact encoding, no large loops

### Developer Workflow

1. Write trap in Solidity (Foundry project)
2. Configure `drosera.toml`
3. `forge build` → `forge test` (fork mainnet at historical blocks) → `drosera dryrun`
4. Deploy — never without a successful dryrun

---

## Part 2: Likely Questions and Strong Answers

### About You

**Q: Tell us about yourself and your experience with Drosera.**

> I've been actively contributing to the Drosera community with a focus on the technical side. I help other community members set up their traps — walking them through the Foundry workflow, debugging common issues like reverting `collect()` functions, and explaining how `drosera.toml` configuration works. I've also built several unique traps of my own, including [mention your specific traps here — what they monitor, what makes them interesting].

**Q: What drew you to Drosera?**

> The idea that security can be decentralized and automated, not just audited once and hoped for the best. DeFi has lost billions because protocols can't defend themselves at runtime. Drosera changes that by letting protocols define exactly what "something is wrong" looks like and having a decentralized network act on it. The fact that it's all Solidity and Foundry made it easy to start building immediately.

**Q: What are your technical strengths?**

> [Tailor this to your actual skills. Examples:]
> - Strong Solidity fundamentals — I understand the EVM execution model, gas optimization, and the view/pure distinction that makes traps work
> - Comfortable with Foundry — writing forks, testing against historical blocks, debugging with traces
> - Good at explaining complex concepts to others — I've helped multiple community members go from zero to deployed trap
> - I think in terms of real-world attack scenarios — when I design a trap, I start from "what would an attacker do" and work backwards

### About Drosera (Technical Knowledge)

**Q: Can you explain how Drosera works at a high level?**

> Protocols write Solidity contracts called traps that define what to monitor and when to act. These traps have two main functions: `collect()` reads on-chain state every block and returns a snapshot, and `shouldRespond()` analyzes the last N snapshots to detect anomalies. Operators run these functions off-chain on shadow EVM forks. When a trap fires, operators sign the result with BLS keys and broadcast it to each other. Once 2/3 agree, the consensus claim is submitted on-chain, and Drosera's contract triggers the protocol's response — like pausing withdrawals or freezing a treasury. The whole thing is verified by zero-knowledge proofs, and operators get slashed if they lie.

**Q: Why must traps be deterministic?**

> Because multiple independent operators need to reach the exact same conclusion from the same data. If `shouldRespond()` depends on anything non-deterministic — storage state, `msg.sender`, block.timestamp, randomness — different operators would get different results. They'd never reach 2/3 consensus, and the trap would never fire. Determinism is what makes decentralized consensus possible.

**Q: Why does trap bytecode live off-chain?**

> It's a security feature called "hidden security intents." If the detection logic were on-chain, an attacker could read it and craft their exploit to avoid triggering the trap — or worse, front-run the response transaction. Keeping it off-chain creates information asymmetry that favors defenders. The attacker doesn't know what the tripwires are.

**Q: What's the difference between `shouldRespond()` and `shouldAlert()`?**

> They work identically — both take a `bytes[]` array of snapshots and return `(bool, bytes)`. The difference is what happens when they return `true`. `shouldRespond()` triggers an on-chain response (calls the response contract). `shouldAlert()` routes to off-chain notification channels — Slack, webhooks, email — configured in `drosera.alerts.toml.j2`. You use `shouldAlert()` when you need awareness without on-chain action.

**Q: What happens if `collect()` reverts?**

> It breaks the entire monitoring loop. The operator can't get a snapshot for that block, leaving a gap in the time-series data. `shouldRespond()` then gets incomplete data, which can cause missed detections or bad analysis. Worse, if it reverts for some operators but not others (different RPC latency, slightly different state), consensus breaks. That's why `collect()` must always return safe defaults — empty bytes or a zero-valued struct — using try/catch and extcodesize checks.

**Q: Can you walk us through a real-world example of where Drosera would have helped?**

> The Nomad bridge hack in August 2022 — $190M drained. The first attacker pulled 100 WBTC, then once the method went public, hundreds of copycats each withdrew ~202,440 USDC, over 200 times across multiple blocks. A Drosera trap monitoring bridge TVL would have caught the anomalous drain in the first few blocks. With 2/3 operator consensus, it could have triggered an emergency pause. The example implementation in the Drosera repo estimates it would have saved ~$42.4M in WBTC alone. The key insight: this was a multi-block attack where every additional block meant more damage. Drosera's block-by-block monitoring is built exactly for this.

**Q: What makes a good trap vs. a bad trap?**

> A bad trap uses a single threshold — "alert if balance < X." That produces false positives on normal volatility and misses sophisticated attacks that stay just above the line. A good trap combines multiple signals across multiple blocks. For example, comparing a price against its TWAP over 100 blocks, checking whether liquidity dropped on multiple DEXes simultaneously, or scoring governance proposals based on proposer age and funding source. Good traps also never revert, validate all inputs (empty data, zero-length arrays), and use basis-point thresholds instead of absolute values.

**Q: Explain the economics — why would an operator run a trap?**

> Operators earn from Hydration Streams — token flows attached to each trap. 70% is passive: you earn just for being online and running the trap. 20% is active: it accumulates in a bonus pool, and when an incident is detected, half goes to the operator who submits the consensus claim first, half is split among co-signers. The remaining 10% goes to DRO stakers. Protocols can also add Bloom Boost — ETH that incentivizes block builders to prioritize the emergency response transaction. So operators earn a steady baseline with upside on incidents. The slashing mechanism (SNARK-verified, lose stake and get ejected) keeps them honest.

### About Your Contribution / The Incubator

**Q: How do you see yourself contributing to Drosera's growth?**

> [Pick what fits you best, or combine:]
> - **Builder**: I want to create production-grade traps for real protocols — lending platforms, bridges, DEXes. I can identify what the highest-value monitoring targets are and build traps that protocols would actually want to deploy.
> - **Educator**: I've already been helping community members set up traps. I'd like to scale that — creating guides, tutorials, walkthroughs, maybe template traps that cover the most common security patterns. Lowering the barrier to entry means more protocols protected.
> - **Both**: I think the most effective contribution is building real traps and then teaching others how to build them. When I create a new trap pattern, I can document the thinking behind it so others can learn and adapt it.

**Q: What kind of traps or projects would you want to work on?**

> [Tailor to your interests. Examples:]
> - Traps for major lending protocols (Aave, Compound, Morpho) — monitoring collateralization ratios, flash loan patterns, oracle staleness
> - Bridge security traps — TVL monitoring, cross-chain message verification, withdrawal pattern analysis
> - Governance defense — detecting whale accumulation before votes, proposal front-running, insider manipulation
> - Novel patterns — cross-protocol contagion detection (if protocol A gets exploited, what happens to protocol B?), MEV-aware monitoring

**Q: What challenges have you faced building traps, and how did you solve them?**

> [Think about your actual experience. Common ones:]
> - `collect()` reverting because I forgot to handle the case where a target contract didn't exist — solved with `extcodesize` check and try/catch
> - Getting different results across test runs because I accidentally used `block.timestamp` in `shouldRespond()` instead of keeping it pure
> - Snapshot encoding being too large — switched to basis-point representations and smaller int types
> - Figuring out the right `block_sample_size` — too small and you miss multi-block attacks, too large and you waste operator resources

**Q: What would you like to see improved in Drosera?**

> [Be genuine but constructive. Ideas:]
> - More example traps targeting real mainnet protocols with documented attack scenarios
> - Better tooling around `drosera dryrun` — more verbose output, historical block simulation
> - A trap registry or marketplace where builders can publish and protocols can discover traps
> - Documentation on advanced patterns like feeder contracts and progressive escalation
> - Cross-chain trap support as DeFi becomes increasingly multi-chain

**Q: How do you explain Drosera to someone who has never heard of it?**

> It's a decentralized security system for smart contracts. Protocols write small monitoring contracts that define "what does an attack look like?" A network of independent operators runs these checks every block. When enough of them agree something is wrong, an emergency response fires automatically — like pausing the protocol before more funds are drained. No single person controls it, and the math proves it's honest.

---

## Part 3: Numbers Worth Knowing

| Stat | Value |
|---|---|
| DeFi losses in 2022 | $3.8 billion |
| Nomad hack total | ~$190M |
| Nomad — estimated saveable by Drosera | ~$42.4M (WBTC alone) |
| Wormhole hack | $321M (120,000 wETH) |
| Euler hack | $197M |
| Static analysis detection rate | ~26% of audit findings |
| Dynamic analysis detection rate | ~37% of audit findings |
| Data validation flaws in audits | 36% of findings |
| Access control issues in audits | 10% of findings |
| Operator consensus threshold | 2/3 majority (BLS signatures) |
| Passive reward share | 70% of Hydration Stream |
| Active reward share | 20% of Hydration Stream |
| Staking reward share | 10% of Hydration Stream |

---

## Part 4: Things to Avoid

- **Don't bluff.** If you don't know something, say so and explain how you'd find the answer. Intellectual honesty > pretending.
- **Don't be generic.** Reference specific traps you've built, specific people you've helped, specific problems you've solved.
- **Don't only talk tech.** They're also assessing judgment, communication, and whether you can help others. Show that you can explain things clearly.
- **Don't forget to ask questions.** This is a two-way conversation. Good questions to ask them:
  - What does the Incubator look like day-to-day? What kind of tasks and deliverables?
  - Which protocols or verticals is Drosera prioritizing for adoption?
  - Are there specific trap patterns or use cases the team wants to see built?
  - How does the team see the educator vs. builder split in terms of what's needed most right now?
  - What does success look like for someone in this program?
  - Is there a roadmap for features like cross-chain traps or restaking integration that contributors should be aware of?

---

## Part 5: Quick Self-Checklist Before the Call

- [ ] I can explain what Drosera is in 30 seconds
- [ ] I can explain `collect()`, `shouldRespond()`, and why they have their constraints
- [ ] I can walk through how operator consensus works (BLS → 2/3 → submit → response)
- [ ] I can explain at least one real-world hack case study and how Drosera would have helped
- [ ] I have specific examples of traps I've built and people I've helped ready to mention
- [ ] I have a clear answer for "where do you want to contribute"
- [ ] I have 3-4 questions to ask the team
- [ ] Telegram account is set up
- [ ] I've tested my camera/mic and the meeting link works
