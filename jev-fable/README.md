# jev-fable

A layer that answers an agent's bounded decisions: routing, classifying, is-this-safe, and whether a human should look. It asks typed questions and gets typed answers, with Claude Fable 5.1 as the judge.

> **Status: planning.** No library code exists yet. The implementation plan is in [`docs/plans/2026-09-26-jev-fable-decision-layer.md`](docs/plans/2026-09-26-jev-fable-decision-layer.md). This folder lives inside the BCC-FRK repo for now and will move to its own repository. Keep it self-contained: nothing here may import from or depend on the parent repo.

## The idea

An agent makes many small decisions per run, and today each one is usually a full generative LLM call. This project follows the "Jev" pattern described by Carnage (@0xCarnagee) in "Jev Engineering: 10 steps to make your agent brain 200x faster" (September 2026). Every decision is asked as one of three question types:

| Type | Asks | Returns |
|---|---|---|
| `noul` | a yes/no question | probability the statement is true |
| `choice` | pick one of your declared options | the option, plus a confidence |
| `score` | rate against your ordered levels | the level, plus a confidence |

All the questions about one piece of state go in **one request**. Every answer is an `enum` in a JSON schema, so the reply can be wrong but it can't be malformed. A **confidence gate** then decides one of three outcomes: act, reject, or hand the decision to a human.

## Honest trade-offs

Claude Fable 5.1 is not the cheap, 70 ms classifier the article describes.

- **Price:** it costs $10 per 1M input tokens and $50 per 1M output tokens. The article claims $0.042 per 1M input tokens for Jev, and the article's own claims weren't checked for this plan.
- **Latency:** thinking is always on, so expect replies in seconds.
- **Probabilities:** the API doesn't return token probabilities, so probabilities come from a calibration table fitted on labeled data. Until that table exists, the numbers are a labeled starting guess.

See the "Reality check" section of the plan for the full comparison, and for the plan's step that measures real latency and cost before anything ships.

## Planned surface

- `src/`: the library, `createJevClassifier()` and `noul()` / `choice()` / `score()`.
- `bin/jev.js`: a CLI with two commands, `classify` (any questions over any state) and `route` (recommends a model tier for a task).
- `bin/jev-guard.js`: an opt-in Claude Code `PreToolUse` hook that judges risky Bash commands.
  - Off unless `JEV_GUARD=1` is set.
  - A cheap code check runs first; only commands it can't classify go to the model.
  - When the judge is unsure or fails, the decision goes to the human (`ask`).
- `bin/jev-eval.js`: a live eval runner that reports accuracy, false-allows, latency and cost per decision, and fits the calibration table.

## Data egress warning

When enabled, the guard sends each Bash command it can't classify locally, plus the working directory, to the Anthropic API. Obvious secrets are removed first, but that is best-effort. Claude Fable 5.1 requires 30-day data retention. Don't enable the guard where that is not acceptable.

## Development

Requires Node.js 20 or newer.

```bash
npm install
npm test
```
