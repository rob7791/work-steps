# Istruzioni per gli agenti

## Work (`.work/`)

I work in `.work/<nome>/` (`entrypoint.md`, `plan.md`, `tasks-step-*.md`) si leggono e si modificano
**solo** con la CLI `wk`: mai editare a mano checklist ed entrypoint.

- Prima di toccare un work leggi `.agents/skills/wk/SKILL.md` (regole d'uso).
- Comandi, filtri e formato: `wk help`.
- Binario: `wk` nel PATH, altrimenti `cli/zig-out/bin/wk`
  (build: `cd cli && zig build -Doptimize=ReleaseSafe`).

## Sviluppo di questo repository

- CLI in Zig 0.17.1 (`cli/`): `zig build`, `zig build test`.
- UI di avanzamento: `npm start` (Node, nessuna dipendenza), http://localhost:4317.
- Commit: Conventional Commits.
