# CLAUDE.md (jev-fable)

Guidance for agents working inside `jev-fable/`.

## This folder is its own project

- It will be split out into its own repository, so treat `jev-fable/` as the repo root.
- Never `require` anything outside this folder, and never add paths like `../../scripts`.
- The parent repo's rules, hooks and test runner don't apply here, and this folder's tests don't run in the parent's CI.
- Run every command from inside `jev-fable/`.

## Plan

Work from `docs/plans/2026-09-26-jev-fable-decision-layer.md`, task by task. Each task is test-first: write a failing test, watch it fail, implement, watch it pass, commit. Tick each checkbox as you finish the step.

## Stack and conventions

- Node.js 20 or newer, plain CommonJS (`require` / `module.exports`), no TypeScript, no build step.
- Tests use `node:test` and `node:assert/strict`. Name them `tests/*.test.js` and run them with `npm test`.
- File names are lowercase with hyphens.
- Call Claude only through the official `@anthropic-ai/sdk`. Never guess SDK method or class names; check them against the installed package.

## Claude Fable 5.1 API rules for this project

- Model `claude-fable-5-1`. Don't change it unless the user asks; make it configurable with `JEV_MODEL`.
- Never send `thinking`, `temperature`, or a forced `tool_choice` (`any` / `tool`). All three return 400 on Fable 5.1.
- Get answers through structured outputs, `output_config.format` with `type: "json_schema"`, and limit every answer to an `enum`. Don't use `minimum` or `maximum` in the schema.
- Check `stop_reason` before reading `content`. A `refusal` or `max_tokens` reply goes to the human, never to allow.
- Find the answer with `content.find(b => b.type === 'text')`, never `content[0]`.

## Safety rules for the guard hook

- It is off by default and only switches on with `JEV_GUARD=1`.
- When it's unsure, errors, times out, or gets a refusal, the result is `permissionDecision: "ask"`. It never silently allows and always exits 0.
- It sends only `{ command, cwd }`, after removing secrets, and never the conversation transcript.
- It honors `JEV_FAKE_REPLY` only when `NODE_ENV=test`.

## Spending money

Live API calls, including the Task 1 spike and the Task 11 eval, cost real money. Show the estimated cost and get the user's approval before running them.
