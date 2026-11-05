---
name: wk
description: Usa la CLI `wk` per creare, leggere e aggiornare i work a checklist (cartelle `.work/<nome>/` con entrypoint.md, plan.md e tasks-step-*.md). Da usare per iniziare o pianificare un nuovo work, riprendere un work, trovare la prossima voce, spuntare/aggiungere/modificare voci, classificare per la delega e gestire dipendenze, filtrare per tag o chiavi, aggiornare l'entrypoint — sempre senza editare a mano i markdown.
---

# wk

CLI per i work a checklist. Non modificare a mano checklist ed entrypoint: usa `wk`.

- Binario: `wk` nel PATH, altrimenti `cli/zig-out/bin/wk` del repo work-steps (build: `cd cli && zig build -Doptimize=ReleaseSafe`).
- Per comandi, filtri e formato: `wk help`, `wk help <comando|format|filters>`. Non servono altre istruzioni.

## Regole d'uso

- Per creare un work segui `wk help init`.
- Se un comando avvisa (stderr) che il formato dei documenti è più vecchio, esegui `wk migrate --from N` come indicato (dettagli: `wk help migrate`).
- Se nel progetto ci sono più work indica sempre quale con `-w DIR` (senza, `wk` si ferma e li elenca).
- Per riprendere un work usa `wk steps` e `wk next`. Non leggere `entrypoint.md` né `plan.md` come file: il plan si legge a sezioni (`wk plan`, poi `wk plan "titolo"`) solo quando la voce lo richiede; l'entrypoint contiene solo `Current task` (se `wk validate` lo segnala troppo lungo, `wk entry slim`).
- Prima di scrivere voci, guarda chiavi e tag già in uso (`wk steps`, poi `wk keys` / `wk tags`): usa quelli, non inventarne di simili. Gli avvisi su stderr ("chiave nuova", "tag nuovo") vanno letti e, se è lo stesso concetto, la voce va corretta.
- Leggi il minimo: filtri, `--count`, `--brief`, `--fields`, `--limit` (vedi `wk help output`). I campi lunghi compaiono accorciati con `[+N car.: wk get ID --fields chiave]`: leggili interi solo se servono alla voce su cui agisci.
- Scrivi breve: ogni valore (`evidenza`, `result`, domande, `entry set`) è un esito di poche righe con il riferimento a un file del repository per i dettagli; il tool rifiuta i testi oltre il limite. Non riscrivere negli entrypoint/campi ciò che sta già nel codice, nei commit o nei file.
- Per delegare: `wk waves --mode isolated` / `wk list --delegable`; passa al sottoagente l'ID e il contesto che gli serve (non è nel tool). Se durante il lavoro emerge una dipendenza o serve il contesto complessivo: `wk dep add` / `wk classify --mode integrated --reason …`, poi fermati e riferisci (vedi `wk help delegation`).
- Dipendenze: `--needs`/`--needed-by` sono solo dirette (per le transitive `wk deps ID --up|--down`). Una dipendenza con ID inesistente viene ignorata nei calcoli, quindi la voce non risulta bloccata: `wk validate` la segnala, va corretta con `wk dep rm|set`.
- Modalità automatica: solo su richiesta esplicita dell'utente (`wk help auto` la definisce per intero). Se manca il limite di voci chiedilo, poi `wk auto start --limit N [--delegate] [--wait MINUTI]` (`--delegate` se l'utente chiede le deleghe: poi `wk auto status` ti dice quando delegare; leggi `wk help auto` per intero, senza `head`); dopo ogni voce `wk auto status` e continui finché `continue` è true. Ogni voce che inizi finisce in `wk check --result` (verificata) o `wk hold "domanda"` (serve input che non hai), mai in un resoconto. Finché c'è altro lavoro NON fare domande in chat: parcheggia la voce (con `--option`/`--default` se le risposte sensate sono poche) e vai avanti; l'utente può rispondere dalla dashboard e `wk auto status`/`wk next` ti segnalano le risposte (`answered`, da leggere con `wk get ID --fields id,asked,answer`). Quando `wk auto status` dà `ask_user` (non resta altro e mancano solo risposte) NON restare in attesa: presenta subito le domande in chat con lo strumento nativo di domande del tuo CLI (`wk questions` ha opzioni e proposta; in più chiamate se serve; senza strumento, scrivile per intero), registra con `wk reply ID "risposta" …` e riprendi; se l'utente rimanda, è uno stop. `waiting_for_answers` = attesa dalla dashboard richiesta dall'utente (`wk auto wait`). Una sessione già registrata (`wk entry get`) non si riprende senza richiesta esplicita. Nel resoconto: il motivo di stop da `wk auto status`, le domande ancora aperte per intero, poi `wk auto stop` (il tool lo rifiuta finché `wk auto status` dà `continue: true`: chiudere uno step o un traguardo non è uno stop; `--force` solo se l'utente ti ha chiesto di fermarti o ha rimandato le domande). Se l'utente ti dice di fermarti, chiudi la sessione con `wk auto stop --force` e riporta lo stato. Non lanciare `wk reply` senza argomenti: è interattivo, per l'utente.
- Rimandare una domanda è una scelta dell'utente (dashboard, o te lo dice in chat): registrala con `wk defer ID --note "cosa si aspetta"`; non riscrivere la domanda, non mettere "Rimanda"/"Non ancora" tra le `--option` né come `--default` (`wk hold` le rifiuta). Le rimandate si vedono con `wk questions --deferred`: non riproporle, citale nel resoconto.
- Deleghe in parallelo (rispetta "Politica deleghe" dell'entrypoint): `wk list --delegable`, `wk claim`, `wk brief`, poi rivedi gli esiti. Se sei un sottoagente: lavora solo sulla voce assegnata e usa `wk hold` / `wk dep add` / `wk classify` invece di chiedere o improvvisare.
- Rischi: un sottoagente è affidabile quanto la classificazione `isolated`, quindi rivedi gli esiti prima di dipendere da essi; il tool non impedisce che due sottoagenti tocchino gli stessi file, quindi non delegare insieme voci che li condividono; l'autonomia lunga si ferma alle autorizzazioni dell'entrypoint e al limite dato dall'utente; la modalità automatica non è persistente (non attivarla da sola perché il work è stato lavorato così); non modificare i file a mano mentre i sottoagenti lavorano.
- Spunta (`check`) solo ciò che è concluso e verificato, non ciò che è stato solo tentato.
- Prima di aggiungere una voce cerca se esiste già. Una voce nuova nasce senza dipendenze: se `wk add` lo avvisa, collegala subito (`wk dep add`), soprattutto quando la crei spezzando una voce che bloccava altre, altrimenti nessuna la aspetta.
- Prima di interrompere, aggiorna "Prossima azione" (e blocchi/contesto se cambiati) con `wk entry set`.
- Nessun segreto, credenziale o dato personale in etichette, chiavi o entrypoint.
- Se un comando fallisce, leggi l'errore e `wk help <comando>`; non aggirare il tool editando i file.
