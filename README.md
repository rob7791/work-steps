# Work Steps
Viewer read-only dell'avanzamento dei work (`entrypoint.md` + `tasks-step-*.md`).

    npm start        # http://localhost:4317  (PORT=... per cambiare)

- Zero dipendenze (Node ≥ 18), solo localhost.
- Percorsi configurabili da UI (⚙ Percorsi) → `~/.config/work-steps/config.json` (se esiste ancora il vecchio `~/.config/step-harness/config.json` e il nuovo no, viene usato quello).
  Accetta una cartella `.work`, un singolo work o la radice di un repo.
- Macroaree = file `tasks-step-*.md`; voci = checkbox; note = righe indentate sotto la voce e sezioni dopo la checklist.

## Agenti

La skill `wk` vive in `.agents/skills/wk/` (cartella letta da Codex e Antigravity CLI);
`.claude/skills/wk` è un link per Claude Code. `AGENTS.md` raccoglie le istruzioni comuni e
`CLAUDE.md` lo importa. Nei progetti che usano `wk`, copiare la cartella `wk` in `.agents/skills/`
(più il link in `.claude/skills/` se si usa Claude Code) e aggiungere le righe "Work" di `AGENTS.md`.

## Plugin di Claude Code

Il repository è anche un plugin (`work-steps`): skill `wk` + binario + due hook.

    /plugin marketplace add ~/workspace/step-harness      # oppure l'URL del repository git
    /plugin install work-steps@work-steps

- **Skill**: `.agents/skills/wk` (la stessa che leggono Codex e Antigravity), come `work-steps:wk`.
- **Binario**: `bin/wk` è un lanciatore che sceglie `bin/<os>-<arch>/wk` (linux, macos, windows × x86_64, aarch64).
  Le build si generano con `scripts/build.sh [target…]` (zig 0.17.x, da un albero git pulito) e si
  committano per pubblicare il plugin. Senza binari il lanciatore usa `cli/zig-out/bin/wk`, se c'è.
- **Hook** (`hooks/hooks.json`), solo `SessionStart` e `Stop`, entrambi `wk hook …`, e **solo in un progetto con
  un work** (`.work/…`): altrove non stampano e non scrivono nulla.
  - `SessionStart`: ricorda di usare `wk`, dove sta il binario e, dopo una compattazione, che una sessione
    automatica è attiva; una sessione di una conversazione precedente non si riprende.
  - `Stop`: se la modalità automatica avviata in questa conversazione ha lavoro disponibile
    (`wk auto status` → `ok`) impedisce all'agente di fermarsi. Domande all'utente, limite raggiunto, fine del
    lavoro, `wk auto stop --force` e tre richiami senza progressi lo lasciano fermare.
- Per provarlo senza installare: `claude --plugin-dir ~/workspace/step-harness`. Verifica: `claude plugin validate .`.
- Windows: il binario si compila, ma senza lock tra scritture concorrenti (`wk` in parallelo da più sottoagenti).

## Licenza

MIT, vedi [LICENSE](LICENSE).
