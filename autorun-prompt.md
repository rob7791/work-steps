Modalità automatica sul work `.work/nome-work`, con deleghe. Limite: 100 voci.

<!--
Cosa va nel prompt: attivazione esplicita, work, deleghe sì/no, limite di voci.
`--delegate` lo imposta l'agente quando scrivi "con deleghe".
Il resto è nella skill e in `wk help auto` (procedura, condizioni di stop, resoconto);
le autorizzazioni e la politica deleghe stanno nell'entrypoint ("Autorizzazione attuale",
"Politica deleghe": impostabile con `wk entry set "Politica deleghe" "max 3 in parallelo, modello …"`).

Come gestisce le domande:
- finché c'è lavoro disponibile l'agente NON ti interrompe: mette le voci in attesa e va avanti; le domande
  compaiono nella dashboard (pulsante "Domande", titolo della scheda, avvisi opzionali) e puoi rispondere lì;
- quando non resta altro da fare perché mancano solo risposte, le presenta subito in chat con lo strumento
  nativo di domande del suo CLI, registra le risposte e riprende;
- se le rimandi, si ferma e le riporta nel resoconto.

Varianti
- risposte solo dalla dashboard, con pazienza:  … Limite: 100 voci. Attendi le risposte dalla dashboard fino a 30 minuti prima di chiedermele in chat.
- senza deleghe:   Modalità automatica sul work `.work/nome-work`. Limite: 100 voci.
- con priorità:    … Parti dallo step 2 e lascia per ultime le voci di step 8.
- primo giro:      … Limite: 5 voci. (poi rivedi gli esiti e alza il limite)
-->
