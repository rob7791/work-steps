---
name: wk-brief
description: Colloquio iniziale per definire un nuovo work prima di crearlo. Da usare quando l'utente vuole pianificare un lavoro nuovo o ancora vago ("voglio pianificare…", "nuovo work per…", "facciamo il brief"). Non propone soluzioni né implementa: chiarisce obiettivi, ambiguità e decisioni aperte con domande mirate, poi crea il work con `wk`. Per riprendere o usare un work esistente serve la skill `wk`.
---

# wk-brief

Modalità briefing: colloquio iniziale per definire cosa va fatto, prima che esista il work.

## Regole

- Non implementare nessuna funzionalità: niente codice, niente modifiche ai file del progetto.
- Non ipotizzare soluzioni concrete e non entrare nei dettagli tecnici: resta ad alto livello, sul *cosa* e sul *come pianificarlo*.
- Esplora il progetto il minimo indispensabile (al massimo `README.md` e `AGENTS.md` per orientarti, e solo se servono): il colloquio è con l'utente, non con il codice.

## Obiettivi

- Capire che cosa l'utente vuole ottenere.
- Individuare ambiguità, vincoli mancanti e decisioni aperte rilevanti per il risultato.
- Distinguere ciò che l'utente ha confermato da ciò che è un'ipotesi.
- Fare domande mirate di chiarimento, con lo strumento nativo di domande del tuo CLI (in Claude Code `AskUserQuestion`), poche per volta e solo se la risposta cambia il piano.

## Uscita dal briefing

Quando gli obiettivi sono chiari:

1. Riassumi in poche righe: obiettivo, vincoli, ipotesi, decisioni ancora aperte, ordine di massima degli step. Chiedi conferma di creare il work.
2. Con la conferma crea il work con `wk` (leggi la skill `wk` e `wk help init`): `wk init`, `wk new-step`, `wk section set` per obiettivo, vincoli e ipotesi in `plan.md`/step, `wk add` per le voci. Niente copia del colloquio: il work deve bastare a chi riparte da zero.
3. Ogni decisione ancora aperta diventa una voce con `wk hold ID "domanda" [--option …]`: compare nella dashboard e l'utente può rispondere o rimandarla.
4. Controlla con `wk validate`.
5. Chiudi dichiarando che il briefing è concluso e il work creato (percorso e numero di step). Suggerisci all'utente di fare `/clear` (o aprire una nuova sessione) e ripartire con «Riprendi il work `.work/nome`»: il contesto sta nel work, non serve la conversazione.

Dopo la creazione non sei più in briefing: non proseguire con l'esecuzione delle voci se l'utente non lo chiede.
