# Work Steps

Checklist a più step (i *work*) che un agente di codice (Claude Code, Codex, Antigravity) legge e aggiorna con la CLI `wk`,
più una dashboard web per seguirne l'avanzamento e rispondere alle sue domande.
Un work è una cartella `.work/<nome>/` con `entrypoint.md`, `plan.md` e `tasks-step-*.md`: non si modifica a mano, solo con `wk`.

## Per iniziare

**1. Installa il plugin** (Claude Code): skill `wk`, binario e hook, tutto insieme.

    /plugin marketplace add rob7791/work-steps
    /plugin install work-steps@work-steps

Con Codex o Antigravity, o senza plugin: vedi [Agenti](#agenti). Serve `wk` nel PATH solo per usarlo a mano da terminale
(archivio per la tua piattaforma nelle Release, oppure `scripts/build.sh`).

**2. Chiedi all'agente di creare o riprendere un work**, in chat e in linguaggio naturale:

- «Crea un work per migrare X a Y: pianifica gli step e le voci.»
- «Riprendi il work `.work/nome-work`.»

**3. Per lavorare a voci in autonomia** usa la modalità automatica. Il prompt va scritto così:

    Modalità automatica sul work `.work/nome-work`, con deleghe. Limite: 100 voci.

`con deleghe` permette di affidare le voci isolabili a sottoagenti; il limite è il numero di voci da completare prima di
fermarsi. Varianti (solo risposte dalla dashboard, priorità, primo giro con limite basso) in [`autorun-prompt.md`](autorun-prompt.md).
Il dettaglio per l'agente è in `wk help auto`.

Mentre lavora l'agente non ti interrompe: mette le voci che richiedono una tua decisione **in attesa** e prosegue.
Le domande le vedi, e ci rispondi, nella dashboard. Puoi anche **rimandarle** (pulsante «Rimanda», con una nota su cosa
aspetti): escono dalla coda, restano visibili in «Rimandate» e le voci che ne dipendono restano ferme.

**4. Avvia la dashboard** (a parte, il plugin non la avvia): da un clone del repository

    node server.mjs        # oppure: npm start    → http://localhost:4317   (PORT=… per cambiare porta)

Node ≥ 18, nessuna dipendenza, solo localhost. Al primo avvio aggiungi i progetti da ⚙ Percorsi (una cartella `.work`, un
singolo work o la radice di un repo): la configurazione è in `~/.config/work-steps/config.json`. La dashboard mostra
macroaree (`tasks-step-*.md`), voci e note, e il pulsante «Domande» per rispondere o rimandare; le risposte passano da `wk`,
che usa il `bin/wk` del repository (oppure `WK_BIN`, oppure `wk` nel PATH).

## Agenti

La skill `wk` vive in `.agents/skills/wk/` (cartella letta da Codex e Antigravity CLI);
`.claude/skills/wk` è un link per Claude Code. `AGENTS.md` raccoglie le istruzioni comuni e
`CLAUDE.md` lo importa. Nei progetti che usano `wk`, copiare la cartella `wk` in `.agents/skills/`
(più il link in `.claude/skills/` se si usa Claude Code) e aggiungere le righe "Work" di `AGENTS.md`.

## Plugin di Claude Code

Il repository è anche un plugin (`work-steps`): skill `wk` + binario + due hook.

    /plugin marketplace add rob7791/work-steps      # oppure un percorso locale del clone
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
