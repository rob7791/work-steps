# Agent instructions

## Works (`.work/`)

Read and update works in `.work/<name>/` (`entrypoint.md`, `plan.md`, `tasks-step-*.md`)
**only** through the `wk` CLI. Never edit checklists or entrypoints manually.

- Before touching a work, read `.agents/skills/wk/SKILL.md`.
- Commands, filters, and format: `wk help`.
- Binary: `wk` on PATH, otherwise `cli/zig-out/bin/wk`
  (build: `cd cli && zig build -Doptimize=ReleaseSafe`).

## Repository development

- Zig 0.17.1 CLI (`cli/`): `zig build`, `zig build test`.
- Progress dashboard: `npm start` (Node, no dependencies), http://localhost:4317.
- Commits: Conventional Commits.
