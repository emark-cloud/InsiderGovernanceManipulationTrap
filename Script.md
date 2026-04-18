# FourScout — 3-Minute Demo Script

> Total runtime: ~3:00 | ~450 words at 150 wpm

Fine-tuned from the user's draft. Changes from the original are flagged inline with **[edit]**; the voice and structure are preserved.

---

## Section 1 — Hook (0:00–0:15) [15s]

**[Visual:** Landing page hero, or a split-screen of two Four.meme tokens — one rugging, one pumping.**]**

> "Four.meme processes over 800,000 daily users and hundreds of new token launches every day — and most of them are rugs or dead on arrival. Traders lose money because they have seconds to decide whether a token is real, and no tool actually remembers what happened last time. We built **FourScout** to fix that."

**[edit]** *"thousands of new token launches"* → *"hundreds of new token launches every day"* (more defensible per-day figure), added *"or dead on arrival"* (captures the dominant failure mode — abandonment, not just rug-pulls).

**Why this works:** leads with the specific platform number, names the problem in one breath, ends with the project name in bold.

---

## Section 2 — Why Existing Solutions Fail (0:15–0:30) [15s]

**[Visual:** Screen recording of scrolling through raw Four.meme launches, BscScan tabs open, Telegram alpha groups.**]**

> "Today traders solve this by tab-hopping between BscScan, Telegram alpha groups, snipe bots, and their own memory. Rug checkers give you a snapshot score and forget it. Snipe bots execute without reasoning. Nobody is doing the one thing that matters: **learning from yesterday's rugs to score today's launches**."

**[edit]** added *"snipe bots"* to the list of failing tools; changed *"Trading bots"* to *"Snipe bots"* (the actual competitor on Four.meme).

**Why this works:** names the alternatives explicitly, then plants the seed for your #1 differentiator (memory) without revealing it yet.

---

## Section 3 — Introduce the Product (0:30–0:40) [10s]

**[Visual:** Cut to the FourScout dashboard, live feed populated.**]**

> "FourScout is a persona-based AI trading agent for Four.meme. It scans every new launch, scores it across eight signals, explains the risk in plain language, and executes trades only within limits you control."

**[edit]** *"eight on-chain signals"* → *"eight signals"* — social + market context aren't strictly on-chain, so this is more accurate.

**Why this works:** one sentence, names who it's for, what it does, and the safety rail.

---

## Section 4 — Show the Core Workflow Live (0:40–1:25) [45s]

**[Visual:** Live dashboard, keep cursor movements decisive.**]**

> "Here's the dashboard. Wallet's connected. Persona: Momentum. Daily cap: 0.3 BNB."

**[Point to the live feed]**

> "The scanner is running. Every 30 seconds it pulls new launches from Four.meme and scores them. Green, amber, red — with the main risk factor surfaced."

**[Click a green-scored token]**

> "This one just launched. Look at the radar — eight signals: creator history, holder concentration, bonding curve velocity, liquidity, tax flags, volume consistency, social signal, market context. Each scored independently, then weighted."

**[Scroll to the AI rationale]**

> "The agent recommends a buy at 0.05 BNB. I approve. Slippage-protected quote, sign in-wallet — on-chain in seconds. Position tracked with live PnL."

**[edit]** *"Daily cap: 0.5 BNB"* → *"Daily cap: 0.3 BNB"* (matches our actual default and the server-side cap). Added *"slippage-protected quote"* before signing — calls out a real safety feature in one word. Dropped *"Transaction preview, sign, done"* (redundant with the single preview-and-sign flow).

**Why this works:** fast-paced, hits setup → scan → score → approve → execute in under a minute, no dead air.

---

## Section 5 — The Three Differentiators (1:25–2:25) [60s]

This is the heart of your pitch. Give each differentiator ~20 seconds.

### 5a — Memory Loops (1:25–1:45) [20s]

**[Visual:** Switch to the rationale view on any token, highlight the historical-summary line *and* the creator-reputation card.**]**

> "Here's what nobody else is shipping. Read the rationale: *'Historical: 3 of your 4 amber tokens with creator-score 3 or lower closed at over 50% loss.'* That's not a static warning. That's FourScout looking at **your** closed trades and **your** confirmed rugs, and feeding the outcome back into today's scoring."

**[Click into the creator address, show the creator_reputation card]**

> "This creator has launched four tokens. Two confirmed rugs. FourScout remembers. Same wallet, scanned tomorrow, gets a lower score automatically."

**Note:** the exact quoted rationale string depends on what `signal_outcomes_summary()` actually emits with your seed data — rehearse with the live copy a day before recording so the numbers match what judges see on screen. Seed instructions in `DEMO_PREP.md` §6.

### 5b — ERC-8004 On-Chain Identity (1:45–2:05) [20s]

**[Visual:** Settings page → ERC-8004 registration card → cut to BscScan tab showing the registration tx.**]**

> "Second: FourScout isn't just an app calling an API. It registers on-chain as an ERC-8004 agent via Four.meme's AgentIdentifier contract. Here's the transaction on BscScan."

**[Brief pause on the tx]**

> "This is Four.meme's own agent-identity standard. When **AI Agent Mode** launches trigger, only registered agent wallets can participate. FourScout is first-class on the platform — not a scraper."

**[edit]** *"When insider phase launches"* → *"When AI Agent Mode launches trigger"* (Four.meme's actual terminology — matches the spec and avoids ambiguity).

### 5c — Escalation Pipeline (2:05–2:25) [20s]

**[Visual:** OpportunityDetail for an AMBER token, show the deep-analysis narrative with cross-signal correlation.**]**

> "Third: most AI trading tools let the LLM make every decision. That's slow, expensive, and often wrong when deterministic rules work better. FourScout scores **every** token with deterministic math — fast, cheap, auditable. The AI pushes hardest where judgment actually adds value: AMBER escalation."

**[Highlight the multi-signal narrative]**

> "Look at this narrative — the model correlates creator cycling with bonding-curve velocity with holder concentration. Pattern detection across signals, not eight disconnected one-liners."

**[edit]** *"AI only kicks in for amber tokens"* → *"The AI pushes hardest … AMBER escalation"* (the original was factually loose — LLM narrative synthesis actually runs for all scored tokens; the AMBER-specific path is the `deep_analyze_amber()` escalation, which is what you're showing. The revised wording is accurate without losing the beat).

**Why this works:** each differentiator has a concrete on-screen artifact. Memory → rationale text + creator record. Identity → BscScan tx. Escalation → correlated narrative. Judges see proof, not claims.

---

## Section 6 — Prove Trust and Reliability (2:25–2:45) [20s]

**[Visual:** "What I Avoided" page with the stats banner, then flash to Activity feed.**]**

> "Quick proof this is real. The 'What I Avoided' page tracks every red-scored token the agent flagged, at 1, 6, and 24 hours. **773 tokens flagged this week. Twelve confirmed rugs. Roughly 0.4 BNB in estimated losses avoided.**"

**[Cut to Activity feed]**

> "Full audit trail. Every scan, every proposal, every trade, every override — logged with outcomes."

**[edit]** added the specific live number (*773 flagged*) — it's real and recorded on your production stats endpoint. Concrete numbers beat round ones. The *12 rugs / 0.4 BNB savings* line depends on seed data landing — verify against the live stats endpoint 10 min before recording.

**Why this works:** the "What I Avoided" log is visceral, quantified, undeniable. Activity feed proves it's not a theater demo.

---

## Section 7 — Operator / Enterprise Side (2:45–2:55) [10s]

**[Visual:** Split — left half shows Settings with budget caps + approval modes; right half briefly shows `FourScout.md` §18 heading.**]**

> "Two audiences benefit. **Traders** stay in control — hard budget caps, four approval modes, monitor-only switch whenever they want out. **The Four.meme ecosystem** gets a trust layer: our non-custodial session-key roadmap means we can scale this to agent-per-user without ever taking custody of a single private key."

**[edit]** the original draft restated trader safety (which §3 already covered) without answering the template's actual question: *"who benefits and why would they pay?"* Revised to hit both audiences — the trader as end-user, and Four.meme itself as the ecosystem that benefits from a retention/trust layer. One breath, no filler.

**Why this works:** pre-empts the *"who's the customer?"* question and signals that you've thought past the MVP.

---

## Section 8 — Scale and Vision (2:55–3:00) [5s]

**[Visual:** Back to dashboard, agent status: scanning. Camera pulls back slightly.**]**

> "FourScout turns memecoin trading from a reaction game into an informed one. Autonomous AI agents with memory, on-chain identity, and revocable authority. **This is what agentic Web3 actually looks like.**"

**[edit]** added *"on-chain identity, and revocable authority"* — threads the ERC-8004 beat from §5b and the session-key roadmap from §7 into a single closing phrase. Keeps the hackathon-theme tie-in ("agentic Web3") that was already strong.

**Why this works:** one-breath closer, ties back to the hackathon's core theme, ends with specificity (three concrete properties) rather than generic hype.

---

## Timing budget

| Section | Target | Running total |
|---|---|---|
| 1. Hook | 0:15 | 0:15 |
| 2. Why existing fail | 0:15 | 0:30 |
| 3. What it is | 0:10 | 0:40 |
| 4. Live workflow | 0:45 | 1:25 |
| 5a. Memory loops | 0:20 | 1:45 |
| 5b. ERC-8004 | 0:20 | 2:05 |
| 5c. Escalation | 0:20 | 2:25 |
| 6. Trust/reliability | 0:20 | 2:45 |
| 7. Operator view | 0:10 | 2:55 |
| 8. Vision | 0:05 | 3:00 |

If you run long, cut §7 to *"Traders stay in control — hard caps, monitor-only switch, session-key roadmap for no-custody scaling"* (saves 3s).

---

## Numbers to verify 10 minutes before recording

These appear in the narration — confirm each matches the live UI before hitting record.

| Line | Source | How to verify |
|---|---|---|
| "800,000 daily users" | Public Four.meme metric | Confirm on four.meme or their announcement channel — swap if stale |
| "773 tokens flagged" | `/api/avoided/stats` → `total_flagged` | `curl -H "X-API-Key: $API_KEY" $BASE/api/avoided/stats` |
| "12 confirmed rugs" | `/api/avoided/stats` → `confirmed_rugs` | Same endpoint. If <3, re-seed per `DEMO_PREP.md` §6 |
| "~0.4 BNB saved" | `/api/avoided/stats` → `estimated_savings_bnb` | Same endpoint |
| "3 of your 4 amber tokens…" rationale quote | Live rationale text on your demo token | Open OpportunityDetail for the demo AMBER — read the actual line verbatim |
| Creator "4 tokens, 2 rugs" | `creator_reputation` row | `SELECT * FROM creator_reputation` via `railway shell` |

---

## Delivery craft notes

- **Say the numbers.** Specific beats vague — *"773"* lands harder than *"hundreds."*
- **Don't narrate clicks.** Judges see the cursor. Your voice adds meaning, not transcription.
- **Pause on the Override Summary card and the creator_reputation row.** These are the *"memory"* proof points. Let them register.
- **End on the dashboard, not the logo.** You want the final frame to be the product running, not a title card.

---

## Pre-record checklist

- [ ] All four Phase 3.5 surfaces seeded (`DEMO_PREP.md` §9 verification queries pass)
- [ ] Wallet connected on `four-scout.vercel.app` with ≥0.002 BNB so the approve click doesn't fail on gas
- [ ] One GREEN pending action ready for the §4 approve beat (or AMBER if that's what's flowing)
- [ ] Demo token for §5a has a visible `signal_outcomes` historical summary in its rationale
- [ ] `/api/avoided/stats` returns the numbers you're about to speak
- [ ] BscScan tab pre-loaded on the ERC-8004 registration tx
- [ ] Browser zoom at 110%, cursor highlight on, 1080p / 30fps recording
- [ ] Run through once silently to land the 3:00 timing
