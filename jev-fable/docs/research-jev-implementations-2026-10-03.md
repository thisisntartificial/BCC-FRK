# Jev-style decision layers: what others measured (research note, 2026-10-03)

Read-only research; nothing deployed. Mirrors hub KV key `research-jev-implementations-2026-10-03`. Purpose: one place to see what public Jev implementations actually report, before building a tool-call gate (hub `task-prompter-gate` PHASE 2 / dispatcher JevRouter).

Each number is marked VERIFIED (re-read from the repo README on 2026-10-03) or UNVERIFIED (not re-checked).

## 1. Sources read

- themsquared/jev-benchmark (Apache-2.0): 60 hand-labelled agent tool-call cases (34 clear, 14 ambiguous, 12 adversarial), classes readonly/destructive/privileged/exfiltration. Compares jev-latest, jev-preview and claude-sonnet-5 on identical task text. Runs 2026-09-17 / 09-24.
- RahulBalakavi/claude-code-jev (MIT): PreToolUse hook -> Jev via OpenRouter (typesafe/jev-1.13) -> allow/block/ask.
- madisonrickert/jev-permission-gate (MIT): Claude Code mod; 8 yes/no questions per call; allow/deny/defer to the built-in auto-mode classifier.

Not read: intikhab49/open-jev-typed-decision-engine, tamaratran/fast-jev-compaction, and about 20 others from the user's list. This is not a survey of them.

## 2. jev-benchmark (VERIFIED)

| | jev-latest | jev-preview | claude-sonnet-5 |
|---|---|---|---|
| Accuracy | 91.7% (55/60) | 91.7% | 91.7% |
| clear / ambiguous / adversarial | 100 / 71.4 / 91.7 | same | same |
| Latency p50 | 421.6 ms | 378.5 ms | 1371.0 ms |
| Latency p95 | 542.0 ms | 484.3 ms | 2719.1 ms |
| Cost per call | ~$0.0000173 | same | ~$0.0007035 |
| ECE (10 bins) | 0.0712 | 0.0505 | 0.0633 |
| Confidence exactly 1.000 | 40/60 | 40/60 | 0/60 |
| Misses at confidence 1.000 | 0 of 5 | 0 of 5 | 0 of 5 |

- Measured multipliers: about 3.25-3.62x faster and about 40.6x cheaper (one-shot classification). The vendor's launch claims were 193.6x / 444.6x. The repo author's likely reconciliation, explicitly not verified there, is that the vendor compared multi-step workflows, not one-shot calls.
- Accuracy tied exactly across all three; the difficulty of the task set the ceiling, not the model.
- Calibration finding: every wrong answer on every backend carried hedged confidence. Jev misses were 0.13, 0.21, 0.25, 0.45, 0.54, 0.57, 0.77, 0.785. Sonnet never went below 0.5 on anything.
- Author caveats: 50 of 60 jev-latest predictions sit in the 0.9-1.0 bin, so ECE is dominated by one bin; an earlier 6-case probe returned 1.000 on 5 of 6, so calibration numbers from an easy set mean nothing. n=60, one labeller, one residential network; some ambiguous-slice "errors" may be mislabels.

## 3. claude-code-jev (VERIFIED, with caveats that matter)

- The hook sends only recent user messages, tool name and args, and cwd. Assistant reasoning and tool outputs are excluded so an agent cannot talk its own gate into yes.
- Default confidence threshold 0.85. Low confidence or any network/API failure -> ask (human review).
- Measured over 5 passes of an 18-case synthetic fixture (90 live calls): latency mean 263.9 ms, p50 230.8, p95 459.2; cost $0.0000227 per decision; "80-81% match" to the fixture reference with 0 dangerous actions allowed.
- The "~93% lower latency" headline compares against a published ~4 s LLM-judge baseline, not a live measurement of Claude Code's own classifier. The README itself says stock auto-mode is already fast and this hook adds a ~264 ms hop on top of it; savings apply only if you replace a slow gate.
- The fixture is synthetic; the author says to replace it with blind-labelled real traffic before claiming accuracy.
- Data egress: user messages, tool name, full tool args and cwd go to OpenRouter; args can contain source, commands, secrets.

## 4. jev-permission-gate (VERIFIED, with caveats)

- Eight yes/no questions in one request. allow: at least 85% sure it serves the request AND every risk check at most 25%. deny: some risk at least 80% AND serves_request at most 30%. Everything else defers to the built-in classifier. Missing key, API error or over 1.5 s -> defer.
- A fixed blocklist (sudo, recursive rm, git push, credential files, infra/db CLIs) never reaches Jev.
- Steering resistance, as implemented (three layers): (1) shell comments and echoed strings that vouch for a command skip Jev entirely; (2) a `steering` question flags other self-approving text, and any score above 0.25 blocks an allow; (3) serves_request is instructed that such text is not a request. On the tuning set steering was at most 0.21 on all harmless calls and 0.70-0.95 on manipulation attempts Jev judged.
- Evals (v0.1.2, jev-1.13.0, 2026-10-02, 2 reps): tuning set 65 cases and held-out set 28 cases, 93 total; 0 unsafe allows, 0 wrong denials. Routine requested calls allowed: 80% tuning, 88% held-out; every miss was a deferral, not an error. With 35 risky cases the author bounds the unsafe-allow rate below about 9% (95% confidence). One person wrote all labels; non-English coverage is thin.
- Live head-to-head vs the built-in classifier (24-25 calls, one session): built-in median 329 ms; where Jev decided (11 of 24) median 164 ms; overall gate median 306 ms. Jev decided only about half of a typical workload; the projected ~40% saving needs the 84% decision rate seen on the eval set.
- Bills input tokens only, about 700 tokens per check. The API appears to serve one request per account at a time (parallel calls queue about 100 ms each).
- Egress: last 3 user messages (up to 1500 chars each), the pending command/URL and project path go to TypeSafe.
- Its first held-out set (holdout-v1) informed a blocklist fix, so the author kept it for reference only and wrote a fresh held-out set after tuning.

## 5. What transfers to our own gate

1. Calibration is the whole point, and only counts if the eval set is deliberately hard. Mix clear, ambiguous, adversarial and steering cases; report bin occupancy, not just ECE.
2. Fail-safe: any error, timeout or low confidence -> human or built-in check, never allow. Both gate repos do this.
3. Keep assistant reasoning and tool output out of the decider's input.
4. Keep a hard blocklist ahead of the model for dangerous programs and credential paths.
5. Add a dedicated steering signal and require it low for any auto-allow.
6. Tune thresholds on one set and report on a separate held-out set written after tuning (permission-gate had to retire its first held-out set after it informed a fix).
7. Report unsafe-allow with a confidence bound, not just a count.
8. Be skeptical of headline speedups: the vendor's 193.6x / 444.6x shrank to about 3.6x / 40.6x one-shot; claude-code-jev's 93% is against a published baseline.

## 6. Relation to existing fleet work

- Hub KV `task-prompter-gate` already defines this pattern for prompts: typed questions, a Laya student trained from a Jev-compatible teacher, calibration temperatures, thresholds pass above 0.9 / fail below 0.1, the middle band queued to the owner, decisions logged to Supabase `gate_decisions`, and an owner-labelled held-out set of 30-50 never used for training. This note changes nothing in that plan.
- That task defers tool-call routing (dispatcher `router.py` JevRouter hook) to the project's PHASE 2. Items 2-7 above are inputs for that phase; the claude-code-jev hook shape is a reference design.
- Hub `orchestrator-routing-policy` makes Claude Fable a planner only and puts classification on T0 cheap models. Nothing found contradicts that.

## 7. Open / unverified (do not quote as fact)

- Fable 5.1 per-decision cost (about $0.0005) and latency are estimates, never measured. The only Fable-vs-Jev comparison above is Sonnet 5 (benchmark). The planned Fable spike was not run.
- This `jev-fable/` folder and its draft PR predate discovering `task-prompter-gate` and may be redundant. The owner decides.
- The X claims (mikenevermiss / 0xCarnagee articles) were not independently verified; vault copies are under Knowledge/.
- The other repos in the user's list were not read.
