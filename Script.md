# Proof-of-Model — Pitch Voiceover

*Spoken track for the 10-slide deck. First-person, conversational. The slides carry one idea each; this script carries the detail. Approx. timings per slide — total **~5.5 min spoken**, **~6.5–7 min with the demo**. See "Trim to ~4 min" at the end.*

**Delivery & honesty guardrails (keep these true on stage):**
- The MVP is a deterministic toy net with a single-round, multi-sample check. LLMs and interactive bisection are roadmap — say so.
- The money spine shipped on the **escrow rail (Arbitrum Sepolia)**; **x402 on Arbitrum One is the production intent**. Don't imply x402 is live end-to-end.
- No invented gas number. If asked, it's ~2% parity vs Solidity — feasibility, not a headline multiplier.
- Demo stakes and the ~30s finalize window are a demo setup, not production economics.

---

## Slide 1 · "An agent pays for a frontier model. It gets a cheap one." *(~25s)*

> AI agents are starting to pay each other for work — and most of that work is running models. But when a buyer agent pays for a frontier model, nothing stops the provider from quietly serving a cheap 7B, pocketing the difference, and handing back a plausible-looking answer. The whole agent economy is being built on an honor system. We built the thing that makes it honest.

---

## Slide 2 · "Paid agent inference has no proof layer." *(~30s)*

> Here's the core problem: a buyer gets back an output and a bill — with no way to check either. Your only options today are to trust a reputation score, which is unprovable; re-run the model yourself, which defeats the entire point of paying someone else; or buy a full cryptographic proof that costs more than the inference did. None of those scale to millions of agent-to-agent calls. There is no proof layer.

---

## Slide 3 · "Commit the trace → spot-check a path → slash the cheat." *(~40s)*

> So here's what we do — and notice we don't sell compute, and we don't prove every call. Five steps, all autonomous agents, no human in the loop. The buyer pays per call. The provider runs the model and posts a tamper-proof fingerprint of the exact computation — a Merkle root over its full activation trace — on-chain. A challenger samples a random output neuron and walks the path back to the input. An on-chain Stylus verifier recomputes that one path and checks it matches. Pass, the fee is released. A lie, and the provider's stake is slashed to zero and the challenger gets paid. Commit the trace, spot-check a path, slash the cheat.

---

## Slide 4 · "The bottleneck isn't compute — it's trust." *(~28s)*

> Why now. The picks-and-shovels of the agent economy — payments, identity — are being built fast; the AI-agent market is projected to hit fifty-two billion dollars by 2030. The missing piece is verification: proof that the work you paid for is the work that happened. Every paid agent-to-agent call is an unverified transaction today. The Arbitrum Foundation itself names this a priority. x402 and ERC-8004 gave agents payments and identity — but nobody built the trust layer for *what was actually run*.

*Source on slide: MarketsandMarkets. If pushed, it's a projection, not revenue — own that.*

---

## Slide 5 · "Three agents, four contracts, one Stylus verifier." *(~38s)*

> Here's the whole system. Off-chain, three autonomous agents — a buyer that pays, a provider that serves, a challenger that audits. On-chain, four contracts on Arbitrum: escrow holds the payment, the registry holds identity and stake, the challenge manager runs the optimistic game. The star is the verifier — a Rust contract compiled to WASM through Stylus, doing the Merkle-proof checks and the fixed-point recompute the EVM can't do cheaply. And the human only ever watches a read-only dashboard — no person can send a protocol transaction, which is what keeps this a real agent-to-agent system. It's deployed live on Arbitrum Sepolia.

*Delivery: point at the amber verifier card — that's the deep-engineering core.*

---

## Slide 6 · "A random path — not a random neuron — makes the check sound." *(~40s)*

> Now the subtle part — why the spot-check is actually sound. You anchor at a random *output* neuron and trace back to the immutable *input* layer. To pass while serving a cheaper model, a provider would have to fake a trace consistent with the real weights along *every* sampled path — which means actually running the real model. Checking a single isolated neuron instead passes vacuously, even when the output is wrong — and the paper we follow explicitly rejects that strawman. One path catches a one-node cheat with probability about one over the layer width; multi-sampling drives that toward certainty. This is the accepted protocol from Anchuri et al. at SaTML 2026 — not the strawman.

---

## ▶ DEMO — roll the recorded demo here *(~60–90s)*

*Lead-in line, then cut to video:*

> Let me show you it running.

*Recorded demo beats: two providers advertise the **same** model hash. Provider A runs it honestly — PASS, keeps the fee. Provider B cheats on command — the challenger catches the mismatch on a single sampled node, stake goes to zero on-chain, the bounty is paid. Then one command, `pnpm verify`, reads the chain, decodes the Slashed / BountyPaid events, and prints PASS. None of it is staged.*

*Re-enter live on Slide 7. (Placement is flexible — this can also slot immediately before the close if you want the demo to be the climax.)*

---

## Slide 7 · "We didn't invent a trust model — we borrowed Arbitrum's." *(~35s)*

> And here's the takeaway for this room: we didn't invent a new trust model. The optimistic fraud-proof game that secures the Arbitrum rollup — post a root, open a challenge window, re-execute one step to catch a lie, slash the cheat — is exactly the game we run for inference. A provider commits a trace root instead of a state root; a Stylus verifier recomputes one path instead of re-executing one step; the challenge window and the slashing are identical. We're applying Arbitrum's own security model to the one thing Arbitrum doesn't yet secure — what model actually ran.

---

## Slide 8 · "Four revenue surfaces." *(~28s)*

> The economics are self-policing. Providers stake a slashable bond to play. Buyers pay per call — x402 in production, the escrow rail in our MVP. Challengers earn a cut of slashed stake, so auditing pays for itself. And we take a small protocol fee on every verified call — that's our surface. The more agent inference flows through the rail, the more the rail earns, without us ever touching the model or the compute.

---

## Slide 9 · "Not zkML. Not a compute marketplace. The trust rail." *(~28s)*

> People will try to file us under zkML or decentralized compute. We're neither. We don't zk-prove or re-execute the whole model — that's too slow and too expensive per call. And we don't sell the inference — the compute provider is the party you can't trust. We sit *above* whoever's selling the compute and make cheating catchable and expensive. We're the trust rail.

---

## Slide 10 · "The primitive is proven — and it's running." *(~35s)*

> To close: the verification primitive and the economic game are proven, end-to-end and on-chain. The toy model isn't a weakness — exact-equality recompute *requires* determinism, and the product is the mechanism, not the model size. The roadmap scales the same paradigm to real LLMs with tolerance bands and to multi-round bisection. The full Stylus verifier and contract stack are live on Arbitrum Sepolia right now — and you can verify every bit of it with one command. Thank you.

*Optional verbal ask (the slide has none): end with one sentence — "If you're building agent payments, come talk to us about piloting the rail," or your judges'-vote line.*

---

## Trim to ~4 minutes

If you're on a tight clock, the spoken track compresses cleanly:
- **Slide 3** — drop the per-step walk; say "the provider commits a fingerprint of the computation, a challenger spot-checks one random path, and a Stylus verifier slashes any mismatch."
- **Slide 4** — keep the $52B line and the "unverified transaction" line; cut the rest.
- **Slides 8 + 9** — halve each to two sentences.
- **Slide 6** — keep the "every sampled path = actually run the model" point; drop the ~1/N detail unless a technical judge asks.

That lands ~3.5–4 min of speaking plus the demo.
