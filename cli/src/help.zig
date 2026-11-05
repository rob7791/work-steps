//! Testi di aiuto: pensati per essere letti da un agente.
pub const main =
    \\wk — gestisce i work (checklist a step) senza modificare i markdown a mano.
    \\
    \\USO
    \\  wk <comando> [argomenti] [opzioni]
    \\  wk help <comando|format|filters|output|delegation|auto>
    \\
    \\LETTURA
    \\  steps        Stato di avanzamento per step (macroaree) e totale
    \\  list         Elenca/filtra/ordina le voci
    \\  get ID       Una voce completa
    \\  next         Prossima voce aperta (nell'ordine del documento o di --sort)
    \\  tags         Tag usati, con conteggi
    \\  keys         Chiavi personalizzate usate, con conteggi e valori più frequenti
    \\  reply        Risponde alle domande in attesa (interattivo per l'utente; `reply ID "risposta"` per gli agenti)
    \\  questions    Voci in attesa di una decisione, con la domanda (da porre all'utente in blocco)
    \\  deps [ID]    Alberatura delle dipendenze (--up/--down, --depth, --open)
    \\  waves        Ondate di esecuzione delle voci aperte (cosa si può fare in parallelo)
    \\  validate     Controlla il formato (ID mancanti/duplicati...)
    \\
    \\SCRITTURA
    \\  add          Aggiunge una voce a uno step
    \\  check ID...  Segna come completate   | uncheck ID...  Riapre
    \\  edit ID      Cambia l'etichetta (--label)
    \\  set ID k=v   Imposta chiavi-valore   | unset ID k...  Le rimuove
    \\  tag ID +a -b Aggiunge/rimuove tag
    \\  rm ID        Elimina la voce
    \\  hold/resolve Mette in attesa una voce con una domanda / registra la risposta
    \\  claim/unclaim Prende in carico una voce (es. per un sottoagente) / la rilascia
    \\  brief        Scheda standard di delega per un sottoagente
    \\  classify     Classifica la voce per la delega (isolated|integrated) o riclassifica
    \\  dep          Aggiunge/toglie dipendenze tra voci
    \\  plan         Sezioni del plan: titoli, oppure una sola sezione (`wk plan "titolo"`)
    \\  section      Legge/scrive le sezioni in prosa di step, plan, entrypoint
    \\  step-set     Titolo, fase e prerequisiti di uno step
    \\  assign-ids   Assegna l'ID alle voci che non ce l'hanno (migrazione)
    \\  new-step     Crea un nuovo tasks-step-NNN.md
    \\  step-status  Imposta lo stato di uno step (es. bloccato)
    \\  sync         Allinea Stato degli step e `Current task` dell'entrypoint (di solito automatico)
    \\  entry        Legge/scrive i campi in prosa di `Current task` (Prossima azione, Blocchi...)
    \\  init DIR     Crea un work nuovo
    \\  version      Versione del tool e del formato dei documenti, con le migrazioni note
    \\  migrate      Porta un work a una versione più recente del formato (--from N)
    \\  hook         Per gli hook di Claude Code (plugin): `wk help hook`
    \\
    \\OPZIONI GLOBALI
    \\  -w, --work DIR   Directory del work. Default: $WK_WORK, poi ricerca di `.work/<nome>`
    \\                   risalendo dalla directory corrente (se ce n'è più di uno serve --work).
    \\  --format json|text|ids   Default json (compatto, una riga). `ids` = un ID per riga.
    \\  --brief          Solo id, done, label.
    \\  --full           Valori lunghi per intero (di norma sopra 300 car. sono accorciati, con l'indicazione di come leggerli).
    \\                   Sulle scritture (check, set, hold, classify…) stampa anche la voce aggiornata: di norma rispondono solo
    \\                   {"ok":true,"updated":[ID…]} (text: `ok ID…`), perché l'agente sa già cosa ha scritto. `add` stampa sempre la voce creata (serve l'ID).
    \\  --fields a,b,c   Solo questi campi (id,done,label,step,step_title,group,tags,fields,notes
    \\                   oppure chiavi personalizzate come `owner`, null se assenti).
    \\  --no-sync        Con check/uncheck/add/rm: non aggiornare entrypoint e Stato degli step.
    \\  -h, --help       Aiuto del comando.
    \\
    \\PRIMA DI SCRIVERE: `wk steps` mostra già chiavi e tag in uso; `wk keys` / `wk tags` il dettaglio.
    \\Chiedi il minimo in lettura: `wk help output`.
    \\
    \\Esempi
    \\  wk steps
    \\  wk next --tag backend --sort priority
    \\  wk list --open --step 2 --where owner=marco --brief
    \\  wk check k3f9 && wk next --brief
    \\
    \\Codici di uscita: 0 ok · 1 errore d'uso/dati · 2 validate con problemi.
    \\
;

pub const format =
    \\FORMATO DEI DOCUMENTI
    \\
    \\Un work è una directory con uno o più file `tasks-*.md` (ognuno è uno step/macroarea)
    \\e, a piacere, `entrypoint.md` e `plan.md`. Il tool legge/scrive solo la sezione
    \\`## Checklist` di ogni step; il resto del file non viene mai toccato.
    \\
    \\    # Step 001 — Baseline
    \\    **Stato:** in corso
    \\
    \\    ## Checklist
    \\
    \\    - [x] k3f9 | Raccogliere la versione di PHP
    \\      - tags: infra, php
    \\      - owner: marco
    \\      - priority: 1
    \\    - [ ] p0qz | Confermare il branch di partenza
    \\
    \\  • Voce:   `- [ ]` / `- [x]` + `ID | etichetta`. L'ID è [A-Za-z0-9_-]{1,32}, unico nel work,
    \\            generato dal tool (4 caratteri). L'etichetta è testo libero.
    \\  • Sottoelementi: `  - chiave: valore` (indentati di 2 spazi). Chiavi personalizzate a piacere.
    \\  • `tags` è speciale: valori separati da virgola, ricercabili singolarmente (--tag).
    \\  • Altre righe indentate sotto una voce sono "notes" e vengono preservate.
    \\  • Chiavi riservate (non usabili come personalizzate): id, label, done, step, line, notes, group, fields.
    \\  • `### Titolo` dentro la checklist definisce un gruppo (campo `group`).
    \\  • Versione del formato: `**Versione documenti:** N` sotto il titolo dell'entrypoint (assente = 0,
    \\    formato sperimentale precedente). Indipendente dalla versione del tool: vedi `wk version`.
    \\    Se un comando avvisa che il formato è più vecchio: `wk help migrate`.
    \\
;

pub const filters =
    \\FILTRI (list, next, tags, e dove indicato)
    \\
    \\  --step S         Solo lo step S: `2`, `002`, `step-002` o `tasks-step-002.md` (ripetibile)
    \\  --open | --done  Solo voci aperte / completate
    \\  --tag t[,t2]     Voci con TUTTI i tag indicati (ripetibile, confronto senza maiuscole)
    \\  --any-tag a,b    Voci con ALMENO UNO di questi tag
    \\  --has chiave     Voci che hanno quella chiave valorizzata (ripetibile)
    \\  --where k=v      Chiave uguale a v (senza maiuscole). Operatori: `k!=v` diverso, `k~v` contiene.
    \\                   k può essere una chiave personalizzata, `label`, `id`, `group`, `tags`.
    \\  --match testo    Testo contenuto in etichetta o ID
    \\  --sort chiave    Ordina per chiave (id, label, step, done o personalizzata). Numerica se i
    \\                   valori sono numeri. Le voci senza la chiave vanno in fondo.
    \\  --desc           Ordine decrescente
    \\  --limit N        Al massimo N voci (il campo `total` nell'output è il numero prima del limite)
    \\
    \\  Delega e dipendenze (vedi `wk help delegation`):
    \\  --mode isolated|integrated|unset    classificazione della voce
    \\  --ready | --blocked | --delegable   pronte / bloccate da dipendenze aperte / pronte e isolated
    \\  --no-deps | --has-deps              senza / con dipendenze
    \\  --deps all-done|some-done|none-done stato delle dipendenze
    \\  --needs ID | --needed-by ID         chi dipende da ID / da cosa dipende ID (dirette)
    \\
    \\  Attesa e presa in carico (vedi `wk help auto`):
    \\  --held                              voci in attesa di risposta (`hold`)
    \\  --claimed | --unclaimed | --claimed-by NOME   prese in carico / libere / prese da NOME
    \\
;

pub const cmd_list =
    \\wk list [filtri] [--brief] [--fields ...] [--format json|text|ids]
    \\
    \\Elenca le voci in ordine di documento (o --sort). Output JSON:
    \\  {"total":N,"count":M,"items":[{"id","step","done","label","tags":[],"fields":{}}]}  (titolo dello step: `wk steps`)
    \\Vedi `wk help filters`.
    \\
    \\  wk list --open --tag urgente --sort priority --brief
    \\  wk list --step 3 --where owner~mar --fields id,label,owner
    \\
;
pub const cmd_get =
    \\wk get ID [--brief] [--fields ...]
    \\
    \\Una voce: {"item":{...}}. I valori oltre 300 caratteri sono accorciati con la nota `[+N car.: wk get ID --fields chiave]`:
    \\il testo intero si legge con `--fields chiave` (solo quel campo) oppure `--full`. Errore (exit 1) se l'ID non esiste.
    \\
;
pub const cmd_next =
    \\wk next [filtri] [--brief] [--fields ...] [--any]
    \\
    \\Prima voce aperta che soddisfa i filtri, saltando quelle bloccate da dipendenze, in attesa di risposta
    \\(`hold`) e prese in carico (`claim`); --any le include. Con --sort sceglie la prima secondo quell'ordine.
    \\Se non c'è nulla: {"item":null,"reason":"no_open_items|nothing_available","open","blocked","held","claimed","hint"}.
    \\
    \\  wk next                      # prossimo da fare
    \\  wk next --tag bloccante --sort priority
    \\
;
pub const cmd_steps =
    \\wk steps
    \\
    \\Avanzamento per step e contatori per decidere cosa fare:
    \\  {"work","done","total","open","available","blocked","held","claimed","delegable","keys":{},"tags":{},
    \\   "steps":[{"key","file","title","status","done","total"}]}
    \\available = aperte, senza dipendenze aperte, non in attesa, non prese in carico (quelle che `next` può dare);
    \\delegable = tra le available, quelle `isolated`.
    \\
;
pub const cmd_tags =
    \\wk tags [filtri]
    \\
    \\Tag usati: {"tags":[{"tag","count","open"}]} ordinati per frequenza.
    \\
;
pub const cmd_add =
    \\wk add --step S "Etichetta" [--tag a,b] [--set k=v]... [--id ID] [--after ID] [--checked]
    \\
    \\Aggiunge una voce in fondo alla checklist dello step (o dopo --after ID).
    \\L'ID è generato se non indicato. Stampa la voce creata.
    \\Se il work ha dipendenze, avvisa (stderr) che la voce nuova non ne ha né ne riceve: collegala con `wk dep add`.
    \\
    \\  wk add --step 2 "Verificare i backup" --tag infra,rischio --set owner=marco --set priority=1
    \\
;
pub const cmd_check =
    \\wk check ID [ID...] [--result "esito"]      wk uncheck ID [ID...]
    \\
    \\Completa / riapre una o più voci. Stampa le voci aggiornate (in forma breve).
    \\--result registra l'esito nel documento (campo `result`): breve e verificabile.
    \\Completare toglie l'eventuale presa in carico e l'attesa. Spunta solo ciò che è concluso e verificato.
    \\
;
pub const cmd_edit =
    \\wk edit ID --label "Nuova etichetta"
    \\
    \\Cambia l'etichetta (l'ID non cambia). Per tag e chiavi usa `tag` e `set`.
    \\
;
pub const cmd_set =
    \\wk set ID chiave=valore [chiave=valore ...]       wk unset ID chiave [chiave ...]
    \\
    \\Imposta/rimuove chiavi personalizzate. `tags=a,b` sostituisce tutti i tag.
    \\Il valore è su una sola riga, non vuoto, max 400 caratteri: scrivi esito, riferimento e prossimo passo;
    \\i dettagli vanno in un file del repository (`evidenza_file=docs/…`). `--long` salta il limite (solo se indispensabile).
    \\Chiavi riservate: vedi `wk help format`.
    \\
;
pub const cmd_tag =
    \\wk tag ID +tag1 +tag2 -tag3
    \\
    \\Aggiunge (+, o nessun prefisso) e rimuove (-) tag. Stampa la voce aggiornata.
    \\
;
pub const cmd_rm =
    \\wk rm ID [ID...]
    \\
    \\Elimina le voci (righe e sottoelementi). Output: {"removed":["id",...]}
    \\
;
pub const cmd_assign =
    \\wk assign-ids [--step S] [--dry-run]
    \\
    \\Dà un ID a ogni voce `- [ ] testo` che non lo ha: `- [ ] k3f9 | testo`. Idempotente.
    \\Output: {"assigned":N,"dry_run":bool}
    \\
;
pub const cmd_validate =
    \\wk validate
    \\
    \\Controlla: ID mancanti, duplicati, etichette vuote, step senza `## Checklist`.
    \\Avvisa (warning) se entrypoint.md supera 4 KB, plan.md 16 KB o ci sono campi oltre 400 caratteri.
    \\Output: {"ok":bool,"issues":[{"step","line","problem"}]}; exit 2 se ci sono problemi.
    \\
;
pub const cmd_new_step =
    \\wk new-step [--title "Titolo"] [--phase "Fase"] [--prereq "Prerequisiti"]
    \\
    \\Crea tasks-step-NNN.md (numero successivo) con lo scheletro standard. Stampa il file creato.
    \\
;
pub const cmd_init =
    \\wk init DIR [--title "Titolo del work"] [--first-step "Titolo step 1"] [--force]
    \\
    \\Crea DIR con entrypoint.md, plan.md e tasks-step-001.md nel formato corretto.
    \\Rifiuta se DIR contiene già dei file (salvo --force, che non sovrascrive i file esistenti).
    \\
    \\COME COSTRUIRE UN WORK (ordine consigliato)
    \\  1. wk init DIR --title "…" --first-step "…"
    \\  2. wk new-step --title "…" --phase "…" --prereq "…"          un comando per ogni step/macroarea
    \\  3. wk section set STEP "Obiettivo" "…"                       sezioni in prosa (anche `Criteri di uscita`…)
    \\     wk section set plan "Strategia" -                         e plan.md (testo da stdin)
    \\  4. wk add --step N "…" --tag … --set chiave=valore           le voci di checklist
    \\  5. wk classify / wk dep add                                  delegabilità e dipendenze (`wk help delegation`)
    \\  6. wk entry set "Prossima azione" "…"                        campi in prosa di Current task
    \\  7. wk validate
    \\Interpretati dal tool: checklist, `**Stato:**`, `**Fase del piano:**`/`**Prerequisiti:**`, Current task
    \\(File/Stato/Avanzamento si aggiornano da soli). Libere: titoli e contenuto delle altre sezioni.
    \\Limiti: un solo `## Checklist` per step, un campo per riga, stati: da iniziare, in corso, bloccato, completato.
    \\
;
pub const cmd_sync =
    \\wk sync [--dry-run]
    \\
    \\Allinea i campi derivabili (check/uncheck/add/rm/new-step lo fanno già da soli):
    \\  • `**Stato:**` di ogni step: promosso a `in corso` alla prima voce completata, a
    \\    `completato` quando sono tutte fatte, riaperto a `in corso` se ne riappare una aperta.
    \\    Non retrocede mai e non tocca `bloccato`.
    \\  • entrypoint.md → `## Current task`: File (primo step con voci aperte), Stato, Avanzamento.
    \\    Se Avanzamento manca viene aggiunto sotto Stato.
    \\I campi in prosa (Prossima azione, ecc.) non vengono toccati: usa `wk entry set`.
    \\Output: {"current":"step-001","entrypoint":bool,"dry_run":bool,"changes":[{"target","field","from","to"}]}
    \\
;
pub const cmd_entry =
    \\wk entry [get]                         Campi di `Current task` e versione dei documenti: {"path","format":{"work","tool"},"fields":[…]}
    \\wk entry set "Etichetta" valore...    Imposta (o crea) un campo, es. "Prossima azione"
    \\wk entry unset "Etichetta"            Rimuove un campo
    \\wk entry slim [--dry-run]            Sposta in entrypoint-archive.md tutte le sezioni tranne `Current task`
    \\
    \\L'entrypoint va tenuto minimo: non si legge per riprendere (lo fanno `wk next` e `wk steps`).
    \\`slim` è reversibile (il testo resta nell'archivio, che non va letto); --dry-run mostra solo le dimensioni.
    \\File, Stato e Avanzamento sono gestiti da `wk sync` e non si impostano a mano.
    \\Il valore è su una riga; il resto di entrypoint.md non viene modificato.
    \\
    \\  wk entry set "Prossima azione" "Completare i test di checkout"
    \\  wk entry set "Blocco alla chiusura" "Mancano le fixture ERP"
    \\
;
pub const cmd_step_status =
    \\wk step-status STEP "da iniziare|in corso|bloccato|completato"
    \\
    \\Imposta `**Stato:**` dello step (utile per `bloccato`, che non è mai automatico) e allinea l'entrypoint.
    \\Con voci ancora aperte `completato` viene riportato a `in corso` dal sync; usa --no-sync per evitarlo.
    \\
    \\  wk step-status 3 bloccato
    \\
;
pub const cmd_keys =
    \\wk keys [filtri]
    \\
    \\Chiavi personalizzate in uso: {"keys":[{"key","count","distinct","values":[più frequenti, max 8]}]}.
    \\Usale con i nomi e i valori esistenti: `set`/`add --set` avvisano (stderr) se introduci una chiave
    \\o un tag nuovo e allineano le maiuscole a quelle già presenti.
    \\
;
pub const output =
    \\LEGGERE SPENDENDO POCO
    \\
    \\  wk steps                     panoramica + chiavi e tag in uso (non serve altro per orientarsi)
    \\  wk list --count [filtri]     solo {"total":N}
    \\  wk list --brief              id, done, label
    \\  wk list --fields id,label,owner   solo i campi che servono (chiavi personalizzate comprese)
    \\  wk list --format ids         un ID per riga
    \\  wk list --limit 10 --sort k  i primi N secondo un criterio
    \\  wk next --brief              la prossima voce, senza tag/chiavi
    \\  wk get ID --fields evidenza  un solo campo, intero (nella vista normale i campi lunghi sono accorciati)
    \\  wk plan / wk plan "titolo"   il plan a sezioni, non per intero
    \\  entrypoint.md                non si legge: `wk next` e `wk steps` bastano per riprendere
    \\
    \\Regole pratiche
    \\  • Restringi con i filtri (--step, --open, --tag, --where) invece di leggere tutto e filtrare dopo.
    \\  • `total` nell'output è il numero prima di --limit: se > count, restringi i filtri.
    \\  • Usa `get ID` solo per le voci su cui stai per agire.
    \\  • `check`/`uncheck` rispondono già in forma breve; `--fields ...` per avere di più.
    \\
;
pub const cmd_classify =
    \\wk classify ID [ID...] --mode isolated|integrated|unset [--reason "motivo"]
    \\
    \\Classifica (o riclassifica) la voce per la delega:
    \\  isolated    eseguibile da un sottoagente con contesto circoscritto, senza perdere affidabilità
    \\  integrated  richiede il contesto complessivo del lavoro
    \\  unset       toglie la classificazione (voce non valutata)
    \\Salvato come `mode` / `mode_reason`. Se cambi modo senza --reason il motivo precedente
    \\viene rimosso (sarebbe obsoleto). Riclassifica appena scopri che la voce non è davvero isolata.
    \\
    \\  wk classify k3f9 p0qz --mode isolated --reason "solo API pubbliche, nessun effetto altrove"
    \\  wk classify k3f9 --mode integrated --reason "tocca la stessa logica di a1b2"
    \\
;
pub const cmd_dep =
    \\wk dep add ID DEP [DEP...] [--reason "motivo"]    la voce ID dipende da DEP
    \\wk dep rm  ID DEP [DEP...]                        toglie dipendenze
    \\wk dep set ID [DEP...]                            sostituisce tutte (senza DEP: le azzera)
    \\
    \\Le dipendenze sono ID di altre voci (anche di altri step). Rifiuta ID inesistenti,
    \\autodipendenze e cicli. Una voce con dipendenze aperte risulta "bloccata" (calcolato, non salvato).
    \\Usalo quando durante il lavoro scopri che una voce dipende da un'altra.
    \\
    \\  wk dep add k3f9 p0qz --reason "serve lo schema definito in p0qz"
    \\
;
pub const cmd_deps =
    \\wk deps [ID] [--up|--down] [--depth N] [--open] [--format json|text|ids]
    \\
    \\Alberatura delle dipendenze come lista piatta (preordine, con depth e parent):
    \\  {"root","direction","count","nodes":[{"id","done","label","mode"?,"depth","parent"}]}
    \\  --up    da cosa dipende ID (default con ID)
    \\  --down  cosa dipende da ID: l'impatto (default senza ID)
    \\  Senza ID: tutto il grafo, solo voci collegate (con dipendenze o dipendenti).
    \\  --depth N  si ferma a N livelli sotto la radice; --open  salta i rami già completati.
    \\
    \\  wk deps k3f9 --up --depth 1 --open     dipendenze dirette ancora da fare
    \\  wk deps p0qz --down                    chi viene sbloccato da p0qz
    \\
;
pub const cmd_waves =
    \\wk waves [filtri] [--format json|text|ids]
    \\
    \\Ondate di esecuzione delle voci aperte: la 1ª è eseguibile subito, la 2ª dopo la 1ª, ecc.
    \\I filtri limitano le voci mostrate (le ondate sono calcolate su tutte le aperte).
    \\Output: {"waves":[{"wave":1,"items":[{"id","label","mode"}]}],"unscheduled":[ID in cicli]}
    \\
    \\  wk waves --mode isolated      cosa posso delegare, e in che ordine
    \\
;
pub const cmd_hook =
    \\wk hook session-start | stop        (legge il JSON dell'hook da stdin; lo lancia il plugin, non l'agente)
    \\
    \\Fuori da un progetto con un work (.work/…) non stampa e non scrive nulla.
    \\  session-start  contesto iniziale: ci sono dei work, si usa `wk`, dove sta il binario; dopo una compattazione
    \\                 ricorda la sessione automatica attiva; una sessione di una conversazione precedente non va ripresa.
    \\  stop           blocca l'arresto dell'agente SOLO se una sessione automatica avviata in questa conversazione
    \\                 ha `wk auto status` con reason "ok" (lavoro disponibile). Domande all'utente, limite raggiunto e
    \\                 fine del lavoro lasciano fermare; dopo 3 richiami senza voci completate lascia fermare.
    \\Stato per conversazione in $TMPDIR/work-steps-<session_id>.state.
    \\
;
pub const cmd_plan =
    \\wk plan                  Titoli delle sezioni del plan
    \\wk plan "Titolo"         Solo il corpo di quella sezione
    \\
    \\Il plan non si legge per intero: elenca i titoli e apri solo la sezione che la voce in corso richiede.
    \\Equivale a `wk section ls plan` / `wk section get plan "Titolo"`.
    \\
;
pub const cmd_section =
    \\wk section ls TARGET
    \\wk section get TARGET "Titolo"
    \\wk section set TARGET "Titolo" testo...      (oppure `-` per leggere il testo da stdin)
    \\
    \\TARGET: uno step (`1`, `step-001`), `plan` oppure `entrypoint`. Opera sulle sezioni `## Titolo`:
    \\`set` sostituisce il corpo o crea la sezione in fondo; il resto del file non cambia.
    \\Non si scrivono così la `Checklist` (usa add/check/…) né `Current task` (usa `entry`/`sync`).
    \\
    \\  wk section set 1 "Obiettivo" "Ottenere una baseline verificabile"
    \\  wk section set plan "Strategia" - < strategia.md
    \\
;
pub const cmd_step_set =
    \\wk step-set STEP [--title "Titolo"] [--phase "Fase"] [--prereq "Prerequisiti"]
    \\
    \\Cambia titolo (il prefisso `Step NNN — ` resta) e metadati `**Fase del piano:**` /
    \\`**Prerequisiti:**` dello step; se la riga manca viene aggiunta sotto `**Stato:**`.
    \\Anche alla creazione: `wk new-step --title … --phase … --prereq …`, `wk init DIR --first-step "Titolo"`.
    \\
;
pub const delegation =
    \\DELEGA E DIPENDENZE
    \\
    \\Ogni voce può avere:
    \\  mode: isolated | integrated      (assente = non classificata)   → `wk classify`
    \\  mode_reason: perché              (soprattutto nelle riclassificazioni)
    \\  deps: ID, ID                     da cosa dipende                → `wk dep`
    \\
    \\Stati calcolati (non salvati):
    \\  pronta    aperta, nessuna dipendenza aperta      (--ready)
    \\  bloccata  aperta, almeno una dipendenza aperta   (--blocked)
    \\  delegabile = pronta + isolated, non in attesa e non presa in carico   (--delegable)
    \\
    \\Filtri (list, next, waves, tags, keys): --ready --blocked --delegable --no-deps --has-deps
    \\  --deps all-done|some-done|none-done   stato delle dipendenze della voce
    \\  --needs ID        voci che dipendono direttamente da ID
    \\  --needed-by ID    dipendenze dirette di ID
    \\  --mode isolated|integrated|unset
    \\`wk next` salta le voci bloccate, in attesa e prese in carico (--any per includerle tutte).
    \\Automazione e deleghe in parallelo: `wk help auto`.
    \\
    \\Limiti da conoscere
    \\  • --needs / --needed-by guardano solo le dipendenze DIRETTE. Per quelle transitive:
    \\    `wk deps ID --up` (da cosa dipende, a cascata) / `wk deps ID --down` (cosa viene sbloccato).
    \\  • Una dipendenza il cui ID non esiste più (voce eliminata a mano) viene ignorata nei calcoli: la voce
    \\    non risulta bloccata da lei. `wk validate` la segnala come errore: correggila con `wk dep rm`/`set`.
    \\  • Una voce senza ID non può avere né essere dipendenza: esegui prima `wk assign-ids`.
    \\
    \\Flusso tipico
    \\  agente principale:  wk waves --mode isolated   →  sceglie le voci, le delega con il contesto utile
    \\  sottoagente:        wk get ID; lavora; wk check ID
    \\                      scopre una dipendenza     → wk dep add ID DEP --reason "…"
    \\                      serve il contesto totale  → wk classify ID --mode integrated --reason "…" (e si ferma)
    \\  agente principale:  wk list --mode integrated --open  per riprendere quelle riclassificate
    \\
;
pub const cmd_version =
    \\wk version [--format text]
    \\
    \\Versione del tool e versione del formato dei documenti che questo wk produce e comprende,
    \\con le migrazioni disponibili: {"tool","commit","format","migrations":[{"from","to","summary"}]}.
    \\`wk --version` stampa versione, commit di provenienza (con "-dirty" se compilato con modifiche non committate)
    \\e versione del formato: serve a riconoscere quale binario è in uso.
    \\
;
pub const cmd_migrate =
    \\wk migrate --from N [--dry-run]
    \\
    \\Porta il work dalla versione N del formato dei documenti a quella di questo wk (`wk version`).
    \\N è la versione dichiarata nell'entrypoint: la leggi in `wk entry get` → `format.work`
    \\(0 = non dichiarata, formato sperimentale precedente). Se N non corrisponde a quanto dichiara
    \\l'entrypoint, o se il work è più recente del tool, il comando si rifiuta.
    \\Applica in sequenza le migrazioni necessarie e aggiorna la versione nell'entrypoint.
    \\È idempotente: se il work è già aggiornato risponde {"changed":false}. Dopo: `wk validate`.
    \\
    \\  wk entry get                  →  "format":{"work":0,"tool":1}, "migrate":"wk migrate --from 0"
    \\  wk migrate --from 0 --dry-run     cosa farebbe, senza scrivere
    \\  wk migrate --from 0
    \\
;
pub const cmd_hold =
    \\wk hold ID "domanda" [--option X --option Y …] [--default X]   mette la voce in attesa di una decisione
    \\wk resolve ID "risposta"      toglie l'attesa e registra domanda (`asked`) e risposta (`answer`, `answered_at`)
    \\wk questions [filtri]         domande da rispondere: {"count","deferred":N,"questions":[{"id","step","label","question","options":[],"default"?}]}
    \\wk questions --deferred       le domande rimandate dall'utente (con "deferred", "note"?, "blocks"); non sono da riproporre
    \\wk defer ID [--note "cosa si aspetta"]   l'UTENTE rimanda la risposta: la domanda resta intatta ed esce dalla coda
    \\wk undefer ID                 rimette la domanda tra quelle da rispondere
    \\
    \\Usalo quando una voce richiede una scelta, un'informazione o un'autorizzazione che l'agente non ha:
    \\mettila in attesa e passa oltre, SENZA fermarti a chiedere in chat finché c'è altro lavoro. L'utente vede le
    \\domande nella dashboard appena compaiono (e con `wk reply`) e può rispondere quando vuole.
    \\Scrivi la domanda in modo che chi legge possa rispondere senza altro contesto: cosa serve, perché blocca.
    \\Se non resta altro da fare, l'agente le presenta in chat (`wk auto status` → "ask_user"); fino ad allora si accumulano.
    \\--option (almeno due) offre risposte a scelta; --default è la proposta che l'utente può accettare in un clic.
    \\`next` e `--delegable` saltano le voci in attesa; la risposta le rende di nuovo disponibili.
    \\
    \\Rimandare: spetta all'utente (pulsante "Rimanda" della dashboard, oppure te lo dice in chat). Allora esegui
    \\`wk defer ID --note "cosa si aspetta"` e basta: non riscrivere la domanda, non annotare il rinvio nel testo,
    \\non riproporla in chat. Una domanda rimandata ferma la voce e quelle che ne dipendono, ma non fa fermare
    \\la modalità automatica né compare tra le domande da rispondere: nel resoconto elencala (`wk questions --deferred`).
    \\NON mettere mai "Rimanda", "Non ancora", "più tardi" tra le --option né come --default: `wk hold` le rifiuta.
    \\`wk hold` su una voce rimandata la riporta tra le domande da rispondere (nuova domanda); rispondere o `wk check` chiudono il rinvio.
    \\
    \\  wk hold k3f9 "Il target è 2.4.8-p5 o p4? Cambia la matrice di compatibilità" --option 2.4.8-p5 --option 2.4.8-p4 --default 2.4.8-p5
    \\
;
pub const cmd_reply =
    \\wk reply                      INTERATTIVO (per l'utente, serve un terminale): una domanda alla volta
    \\wk reply --id ID              solo quella domanda
    \\wk reply ID "risposta" [ID "risposta" …]    registra risposte (per gli agenti); nessuna modifica se una non è valida
    \\
    \\Interattivo: per ogni domanda mostra ID, voce, testo, opzioni e proposta. Si risponde con testo libero, con il
    \\numero di un'opzione, `d` per la proposta, invio per saltare, `q` per uscire. Ogni risposta è salvata subito.
    \\Un agente NON deve lanciare `wk reply` senza argomenti (fallisce senza terminale): legge `wk questions` e registra
    \\con `wk reply ID "risposta"` le risposte ottenute dall'utente. Se la risposta inizia con '-', usa `--` prima degli ID.
    \\Le risposte possono arrivare anche dalla dashboard web mentre l'agente lavora.
    \\
;
pub const cmd_claim =
    \\wk claim ID [ID...] [--by NOME]     prende in carico (default NOME: agent)
    \\wk unclaim ID [ID...]               rilascia
    \\
    \\Segna le voci come "in lavorazione" da NOME (campo `claimed_by`): `next` e `--delegable` le saltano,
    \\quindi né l'agente principale né altri sottoagenti le riprendono. Rifiuta voci completate, in attesa,
    \\bloccate da dipendenze aperte o già prese da un altro. `check` e `hold` rilasciano da soli.
    \\
    \\  wk list --delegable --limit 3 --format ids
    \\  wk claim k3f9 p0qz --by sub1
    \\
;
pub const cmd_brief =
    \\wk brief ID [ID...]
    \\
    \\Stampa (testo, non JSON) la scheda di delega per un sottoagente: voce, classificazione e motivo,
    \\chiavi, dipendenze dirette con il loro esito, cosa si sblocca, le regole d'uso di `wk` per il
    \\sottoagente e uno spazio "Contesto fornito dall'agente principale" da completare prima di avviarlo.
    \\Non prende in carico la voce: usa `wk claim`.
    \\
;
pub const auto =
    \\MODALITÀ AUTOMATICA E DELEGHE IN PARALLELO
    \\
    \\In breve
    \\  • `wk auto start --limit N [--delegate] [--wait MIN]`, poi `wk auto status` dopo ogni voce: continui finché "continue" è true.
    \\  • Con --delegate (l'utente ha chiesto "con deleghe") `wk auto status` ti dice quando ci sono voci isolated
    \\    da delegare ("delegable", "hint"): claim → brief → sottoagenti in background (sezione "Con deleghe in parallelo").
    \\  • Mai domande in chat finché c'è lavoro; `hold` e avanti. Quando mancano solo risposte (ask_user) chiedile in chat.
    \\  • Leggi questa guida per intero (non tagliarla con head): il dettaglio sotto è la procedura.
    \\
    \\Che cos'è
    \\  Su richiesta ESPLICITA dell'utente l'agente lavora le voci una dopo l'altra, in continuazione, senza
    \\  aspettare conferme. Finché c'è lavoro disponibile NON fa domande in chat: dove serve una decisione mette la
    \\  voce in attesa (`hold`) e passa alla successiva; l'utente può rispondere in qualsiasi momento dalla
    \\  dashboard (o con `wk reply`) e le voci risposte tornano disponibili. QUANDO NON RESTA ALTRO DA FARE perché
    \\  mancano solo risposte (reason "ask_user"), l'agente NON resta fermo ad aspettare: presenta subito le domande
    \\  in chat e poi riprende. All'utente bastano: il work, se con deleghe, il limite di voci e, se preferisce
    \\  rispondere dalla dashboard, quanto l'agente può attendere prima di chiedere in chat (--wait). Autorizzazioni
    \\  e politica deleghe stanno nell'entrypoint. Il tool fornisce dati e regole di salto; il ciclo lo esegue
    \\  l'agente, ma le condizioni di stop le valuta il tool (`wk auto status`).
    \\
    \\Strumenti
    \\  wk auto start --limit N [--delegate] [--wait MINUTI]   registra la sessione nell'entrypoint (campo "Sessione automatica").
    \\                              --wait = minuti di attesa di risposte DALLA DASHBOARD prima di chiedere in chat (default 0:
    \\                              si chiede in chat appena non resta altro)
    \\  wk auto status              {"continue":bool,"reason":"ok|waiting_for_answers|ask_user|only_deferred|nothing_available|limit_reached",
    \\                              "completed","limit","available","held","deferred","delegate","delegable","answered","answered_ids","wait_left_s","hint"}
    \\  wk auto wait --timeout S    attende (polling, default 60 s) risposte dalla dashboard; consuma il budget --wait
    \\  wk auto stop                chiude la sessione: {"stopped":true,"completed":N}. Rifiutato se `wk auto status` dà
    \\                              "continue": true (nessuna condizione di stop); `--force` solo su richiesta dell'utente di
    \\                              fermarti, domande rimandate o errore bloccante.
    \\  wk steps                    contatori: available, blocked, held, claimed, delegable, answered
    \\  wk next                     prossima voce disponibile (prima quelle con risposta dell'utente); se non c'è: {"item":null,…}
    \\  wk hold ID "domanda" [--option …] [--default …]   mette in attesa una voce; wk questions le elenca
    \\  wk reply ID "risposta"…     registra le risposte ottenute dall'utente (l'utente può usare `wk reply`)
    \\  wk claim ID… --by NOME      prende in carico (nessun altro la riprende); wk unclaim ID…
    \\  wk brief ID…                scheda standard di delega per un sottoagente
    \\  wk check ID --result "…"    completa e registra l'esito nel documento
    \\
    \\"Completate" in una sessione = voci completate adesso meno quelle al via: una voce riaperta fa scendere il
    \\conteggio, una completata da un sottoagente conta una volta.
    \\Una "Sessione automatica" già registrata (la mostra `wk entry get`) appartiene a una sessione precedente: non
    \\riprenderla senza una richiesta esplicita dell'utente; chiedigli se riprenderla o chiuderla (`wk auto stop`).
    \\
    \\Ciclo automatico (agente principale)
    \\  0. Se il limite non è stato indicato dall'utente, chiediglielo. Poi `wk auto start --limit N [--delegate] [--wait MINUTI]`
    \\     (--delegate se l'utente ha chiesto le deleghe: da quel momento `wk auto status` ti segnala le voci da delegare).
    \\  1. wk entry get e wk steps per orientarti (autorizzazioni, politica deleghe, contatori).
    \\  2. wk next → lavora la voce. OGNI voce che inizi finisce in uno stato solo, mai in un resoconto:
    \\       • verificata       → wk check ID --result "esito e verifica"
    \\       • serve input che non hai (decisione, autorizzazione, dato, ambiente) → wk hold ID "domanda" e passa oltre.
    \\         NON chiedere in chat. Domanda autosufficiente: cosa ti serve, perché blocca; usa --option e --default
    \\         quando le risposte sensate sono poche, così l'utente risponde in un clic.
    \\     "La verifica non è ancora sufficiente" NON è un motivo per fermarsi: continua a lavorare finché la voce è
    \\     verificabile; se per verificarla manca qualcosa che non hai, usa hold e scrivi cosa manca.
    \\     Un'azione fuori da "Autorizzazione attuale" dell'entrypoint → hold.
    \\  3. wk auto status dopo ogni voce. Se "continue" è true torna al punto 2, senza eccezioni, salvo:
    \\       • reason "waiting_for_answers" (hai chiesto di attendere la dashboard): `wk auto wait --timeout 120`, poi
    \\         di nuovo `wk auto status`;
    \\       • reason "ask_user": non resta altro da fare, mancano solo risposte → SEZIONE "Domande in chat" qui sotto.
    \\     Le risposte arrivano mentre lavori: `wk auto status` le segnala ("answered", "answered_ids") e `wk next` restituisce
    \\     prima le voci con risposta. Prima di riprenderle leggi `asked` e `answer` (wk get ID --fields id,asked,answer).
    \\  4. Ogni tanto: wk entry set "Prossima azione" "…" (se la sessione si interrompe, il lavoro riparte da lì).
    \\
    \\Domande in chat (reason "ask_user")
    \\  Non aspettare in silenzio che compaiano risposte nei file. Leggi `wk questions` e presentale ADESSO all'utente
    \\  con lo strumento nativo di domande del tuo CLI (se non ce l'hai, scrivile in chat per intero, numerate, con
    \\  opzioni e proposta, e attendi la risposta dell'utente in chat).
    \\    • Raggruppa quante ne consente lo strumento per chiamata; ripeti in più chiamate se sono di più.
    \\    • Opzioni: usa quelle della domanda (--option) e segna la proposta (--default). Se la domanda non ne ha e lo
    \\      strumento le richiede, proponi tu 2-3 risposte plausibili (una sempre "Rimanda"), lasciando il testo libero.
    \\    • Intestazione: ID e voce; il testo della domanda per intero.
    \\  Poi registra TUTTE le risposte in una sola chiamata: `wk reply ID "risposta" ID "risposta" …` (usa `--` prima
    \\  degli ID se una risposta inizia con '-'). Se `wk reply` segnala che una voce ha già una risposta (l'utente ha
    \\  risposto nel frattempo dalla dashboard) non è un errore: rileggi `wk questions` e prosegui.
    \\  Quindi riprendi dal punto 1 del ciclo (`wk auto status` → `wk next`).
    \\  Se l'utente rimanda una domanda (te lo dice in chat, o lo fa dalla dashboard): `wk defer ID --note "cosa si aspetta"`,
    \\  senza riscrivere la domanda né mettere "Rimanda" tra le opzioni. Se non risponde e non rimanda, non riproporla:
    \\  è uno stop (nothing_available), riportalo nel resoconto.
    \\
    \\Condizioni di stop (tutte e sole)
    \\  a. `wk auto status` → "continue": false con reason "only_deferred", "nothing_available" o "limit_reached".
    \\     ("waiting_for_answers" e "ask_user" NON sono stop: si attende la dashboard entro il budget --wait, poi si
    \\     chiede in chat.) "only_deferred": restano solo voci ferme per domande che l'utente ha rimandato
    \\     (`wk questions --deferred`): non riproporle in chat, nel resoconto elencale con quante voci fermano ("blocks").
    \\  b. Errore bloccante dell'ambiente o del tool che non sai aggirare.
    \\  Non sono condizioni di stop: un risultato parziale buono, "aver fatto abbastanza", la lunghezza della
    \\  conversazione, voci ancora disponibili con limite non raggiunto, domande in attesa (si parcheggiano e si va
    \\  avanti; se non resta altro si chiedono in chat). Il limite è un tetto da raggiungere, non un permesso di
    \\  fermarsi prima.
    \\
    \\Se l'utente ti dice di fermarti
    \\  Chiudi subito con `wk auto stop --force` (il tool altrimenti rifiuta) e riporta lo stato con `wk steps`.
    \\
    \\Controllo prima del resoconto finale (sempre)
    \\  Esegui `wk auto status`. Se "continue" è true, NON fermarti: continua dal punto 2 (o attendi, punto 3).
    \\
    \\Resoconto finale
    \\  1. Apri con il motivo dello stop: la reason di `wk auto status` (o l'errore bloccante). Se nessuna condizione
    \\     si è verificata, il resoconto non va scritto: riprendi dal punto 2.
    \\  2. Voci completate con esito e verifica; deleghe e riclassificazioni; avvisi di `wk`; `wk steps`.
    \\  3. DOMANDE ANCORA IN ATTESA (solo se l'utente le ha rimandate o non ha risposto): riportale PER INTERO, numerate,
    \\     con ID, voce, testo, opzioni e proposta (`wk questions --format text`). Non riassumerle ai soli argomenti.
    \\  4. Chiudi con `wk auto stop` (se le domande sono rimandate dall'utente: `--force`; il tool rifiuta lo stop se `wk auto status` dà "continue": true).
    \\
    \\Con deleghe in parallelo
    \\  Politica: campo "Politica deleghe" dell'entrypoint (es. "max 3 in parallelo, modello haiku", impostabile con
    \\  `wk entry set "Politica deleghe" "…"`). Se manca usa un valore prudente: max 2-3 sottoagenti, il modello più
    \\  piccolo adeguato.
    \\  1. wk list --delegable --limit N → verifica che non condividano file o decisioni → wk claim ID --by subN
    \\  2. wk brief ID → completa "Contesto fornito dall'agente principale" → avvia il sottoagente in background.
    \\  3. Nel frattempo lavora in linea sulla prossima voce non delegabile (wk next).
    \\  4. A ogni sottoagente concluso rivedi l'esito (wk get ID --fields id,result). Se non convince: wk uncheck ID e
    \\     rilavorala tu, oppure wk hold ID "…". Poi ricalcola con wk steps e ripeti.
    \\  Il sottoagente: wk get, lavora, wk check --result. Se emerge una dipendenza (wk dep add), serve il contesto
    \\  complessivo (wk classify --mode integrated) o una decisione (wk hold): si ferma e riporta.
    \\
    \\RISCHI DA CONOSCERE
    \\  • Scritture concorrenti: wk blocca la cartella del work durante le scritture, quindi più sottoagenti in
    \\    parallelo non si sovrascrivono. Non modificare i file a mano mentre lavorano.
    \\  • Affidabilità dei sottoagenti: un modello meno capace è affidabile quanto la classificazione `isolated`.
    \\    Parti da voci con un `mode_reason` solido e rivedi sempre gli esiti prima di dipendere da essi.
    \\  • Collisioni sui file: il tool non impedisce a due sottoagenti di toccare gli stessi file o aree. Si evita
    \\    scegliendo cosa delegare insieme (le voci non devono condividere file o decisioni).
    \\  • Autonomia lunga: l'agente procede senza l'utente. I limiti sono le autorizzazioni dell'entrypoint, `hold`
    \\    e il limite di voci/tempo dato nel prompt. Nessun segreto né azioni su ambienti reali senza autorizzazione
    \\    esplicita.
    \\  • Modalità non persistente: va richiesta a ogni sessione; un agente nuovo non deve partire in automatico
    \\    solo perché il work è stato lavorato così.
    \\  • Il tool applica dati e salti (hold, claim, dipendenze), non il comportamento dell'agente: le regole
    \\    di questa pagina vanno seguite, non sono imposte.
    \\
;
