# wk — CLI per i work a checklist

Binario Zig (0.17.1, zero dipendenze) per leggere e modificare i work (`entrypoint.md`, `plan.md`,
`tasks-step-*.md`) senza toccare i markdown a mano. Pensato per agenti: output JSON compatto,
filtri, ordinamenti, errori chiari su stderr (exit 1).

    cd cli
    zig build -Doptimize=ReleaseSafe     # → zig-out/bin/wk
    zig build test
    wk help            # comandi
    wk help format     # formato dei documenti
    wk help filters    # filtri/ordinamenti

Formato di una voce nella sezione `## Checklist`:

    - [x] k3f9 | Etichetta libera
      - tags: infra, php
      - owner: marco

Il tool riscrive solo le righe delle voci modificate; il resto dei file resta identico.
Per migrare un work esistente: `wk assign-ids -w DIR`.

## Sincronizzazione dell'entrypoint

`check`, `uncheck`, `add`, `rm` e `new-step` aggiornano da soli (disattivabile con `--no-sync`):

- `**Stato:**` dello step: `in corso` alla prima voce completata, `completato` quando sono tutte
  fatte, di nuovo `in corso` se ne riappare una aperta. Non retrocede e non tocca `bloccato`.
- `## Current task` di `entrypoint.md`: **File** (primo step con voci aperte), **Stato**, **Avanzamento**.

I campi in prosa (Prossima azione, Blocchi, Contesto…) restano a chi li scrive, con
`wk entry set "Prossima azione" "testo"`. `wk sync [--dry-run]` forza l'allineamento
(utile dopo modifiche manuali ai file).

## Delega e dipendenze

Ogni voce può avere `mode: isolated|integrated` (delegabile a un sottoagente con contesto circoscritto /
serve il contesto complessivo), `mode_reason` e `deps: ID, ID`. Pronte/bloccate si calcolano dalle dipendenze.

    wk classify ID… --mode isolated --reason "…"     # anche per riclassificare
    wk dep add|rm|set ID DEP…                        # rifiuta cicli e ID inesistenti
    wk deps [ID] [--up|--down] [--depth N] [--open]  # alberatura, parziale o intera
    wk waves [--mode isolated]                       # cosa eseguire (in parallelo) e in che ordine
    wk list --ready | --blocked | --delegable | --deps some-done | --needs ID | --needed-by ID

`wk next` salta le voci bloccate. Dettagli: `wk help delegation`.

## Consumi

Il tool sposta la lettura dai documenti ai comandi, e tiene piccoli sia l'output sia i documenti:

- `wk steps` + `wk next` bastano per riprendere: l'entrypoint contiene solo `Current task` (`wk entry slim`
  sposta il resto in `entrypoint-archive.md`, da non leggere) e il plan si legge a sezioni (`wk plan`, `wk plan "titolo"`).
- Nella vista predefinita i valori oltre 300 caratteri sono accorciati con `[+N car.: wk get ID --fields chiave]`
  (`answer`, `hold` e le opzioni mai); `--fields chiave` o `--full` danno il testo intero.
- Testi scritti: max 400 caratteri per campo (`set`, `add --set`, `check --result`), 240 per le etichette, 700 per
  le domande; `--long` salta il limite. `wk validate` avvisa se entrypoint > 4 KB, plan > 16 KB o ci sono campi lunghi.

## Costruire e documentare un work

`wk init`, `wk new-step --phase --prereq`, `wk step-set`, `wk section ls|get|set` (step, `plan`, `entrypoint`)
e `wk validate` coprono la creazione senza editare i file. Guida: `wk help init`.

## Versione dei documenti e migrazioni

L'entrypoint dichiara la versione del formato dei documenti (`**Versione documenti:** N`, assente = 0,
formato sperimentale precedente). È indipendente dalla versione del tool: `wk version` mostra quella
che il tool produce e le migrazioni note. Ogni comando avvisa (stderr) se il work è più vecchio del tool (`wk entry get` riporta `format.work` e `format.tool`): `wk migrate --from <format.work> [--dry-run]`. Un work più recente del tool viene rifiutato.
Per aggiungere una migrazione: nuova voce in `src/format.zig` (`migrations` + ramo in `apply`) e `current`.

## Modalità automatica e deleghe in parallelo

`wk hold/resolve/questions` (voci in attesa di una decisione), `wk claim/unclaim` (presa in carico),
`wk brief` (scheda di delega per un sottoagente), `wk check --result`, contatori in `wk steps` e motivo
quando `wk next` non trova nulla. Le scritture prendono un lock sulla cartella del work: più processi `wk`
in parallelo non si sovrascrivono (senza lock, in prova, circa metà degli aggiornamenti andava persa).
Guida e rischi: `wk help auto`.

## Risposte alle domande (dashboard, `wk reply`, attesa)

`wk hold ID "domanda" [--option …] [--default …]` parcheggia una voce senza fermare l'agente. L'utente risponde
dalla dashboard (pulsante "Domande": le risposte si registrano con `wk reply`, quindi con lock e validazione) oppure
da un terminale con `wk reply` (una domanda alla volta). `wk reply ID "risposta"…` è la forma per gli agenti.
L'agente si accorge delle risposte da `wk auto status`/`wk steps` (`answered`) e `wk next` riprende per prime le voci
risposte. Quando non resta altro da fare e mancano solo risposte, `wk auto status` dà `ask_user`: l'agente le presenta
in chat con lo strumento nativo del suo CLI e riprende. `wk auto start --wait MINUTI` + `wk auto wait` sono opzionali:
attendono prima le risposte dalla dashboard, poi si chiede in chat.
