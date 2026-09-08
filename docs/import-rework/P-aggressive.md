Fetta verticale #P. Ribalta la filosofia conservativa del ticket 13 ora che c'è un umano nel loop: le euristiche **propongono sempre** un valore quando esiste un candidato plausibile. Porta il tasso di conversione al target. Dipende da: Slice M (metrica), N (guasti), O (passo di revisione — **vincolo duro**, vedi sotto).

## Problem Statement

Il ticket 13 vieta esplicitamente di compilare `ruolo`, `azienda`, `titolo`, `istituto`, `nome`, `cognome`, `headline`, e di dedurre livelli CEFR e tag skill. Sul CV di riferimento questo significa **~30 campi su 47 lasciati vuoti per scelta**, non per incapacità: le informazioni sono lì, in un layout perfettamente regolare (`Azienda - Città` / `Ruolo` / `1 Jun 2024 - Current` / descrizione).

La motivazione originale era corretta **dato l'auto-import puro**: un campo sbagliato finisce in un CV salvato e l'utente non sa nemmeno che è sbagliato. Con il passo di revisione della Slice O quella motivazione decade: un suggerimento sbagliato costa una correzione a vista, non un errore silenzioso.

## Solution

- **`ruolo` / `azienda` (e `titolo` / `istituto`)**: dedotti dalle righe che precedono la riga-data del blocco, con **voto per-documento** sull'ordine (vedi sotto).
- **`nome` / `cognome`**: prima riga non vuota del documento, **prima di qualsiasi heading riconosciuto**, senza cifre né `@`, che non sia una voce del dizionario sezioni, composta da 2–4 token capitalizzati. Split convenzionale: primo token = nome, resto = cognome.
- **Livelli CEFR**: riconoscere `A1|A2|B1|B2|C1|C2` e `madrelingua`/`mother tongue` nel blocco Lingue → `LinguaItem` strutturati. Quando la stessa lingua ha più livelli per abilità (Europass: Listening C2 / Reading C2 / Writing C1...), proporre **il livello più frequente** e marcare il campo **incerto**.
- **Skill**: la riga con separatori ripetuti (`|`, `•`, `,`) sotto un heading Skill diventa la lista di `tags`; il resto del blocco va in `markdown`.
- **Heading non riconosciuti** ma con forma da titolo (riga corta, isolata, maiuscola o più alta della mediana): diventano **sezioni custom col titolo originale** invece di colare nella sezione precedente.

### Voto per-documento sull'ordine ruolo/azienda

Il ticket 13 rifiutava questa deduzione perché *"dato un blocco con due righe sopra la data, quale è il ruolo e quale l'azienda?"* — nel CV di riferimento l'ordine è `Azienda` poi `Ruolo`, in un export LinkedIn è l'opposto, e non esiste un ordine universale.

Il ticket 13 ha però ignorato un fatto: **un CV è internamente coerente**. Tutte le esperienze dello stesso documento usano lo stesso ordine. Quindi la decisione **non si prende per blocco, si prende una volta per documento**:

1. Si cercano i blocchi dove un segnale è netto: una riga contiene un marcatore societario (`Srl`, `S.p.A.`, `Inc`, `Ltd`, `GmbH`, `SA`) o il separatore ` - ` con una località; l'altra contiene un lessico di ruolo (`Architect`, `Engineer`, `Developer`, `Manager`, `Lead`, `Analyst`, `Sviluppatore`, `Consulente`, `Responsabile`).
2. Si vota l'ordine sui blocchi con segnale netto.
3. L'ordine vincente si applica a **tutti** i blocchi della sezione. I blocchi decisi per voto e non per segnale diretto sono marcati **incerti** nell'`ImportProposalReport`.
4. Se il voto non raggiunge una maggioranza chiara, si ricade sul comportamento attuale: entrambi vuoti, tutto in `descrizione`.

## User Stories

1. Come utente, voglio che azienda e ruolo di ogni esperienza arrivino già compilati, così non ricopio 20 campi a mano da un blob.
2. Come utente con un CV dove l'ordine azienda/ruolo è invertito rispetto al comune, voglio che l'app lo capisca **dal mio documento** invece di applicare una convenzione fissa.
3. Come utente, voglio che nome e cognome arrivino dalla prima riga del CV.
4. Come utente con un CV Europass, voglio che `English — Listening C2, Reading C2, Writing C1` diventi una voce Lingue con un livello proposto e **segnalato come incerto**, invece di finire in "Da rivedere".
5. Come utente, voglio che la riga `React.js | Flutter | Node.js | Git` diventi una lista di tag skill.
6. Come utente con una sezione dal titolo insolito (`PROGETTI`, `PUBBLICAZIONI`), voglio ritrovarla come sezione custom col suo titolo, non fusa nella sezione precedente.
7. Come utente, voglio che ogni deduzione fragile sia **evidenziata** nel passo di revisione, così so dove controllare.

## Implementation Decisions

- **Vincolo duro di rilascio**: questa slice **non può andare in mano agli utenti prima della Slice O**. Euristiche aggressive senza passo di revisione = auto-import che scrive con sicurezza dei dati sbagliati in un CV salvato: sarebbe peggio dello stato attuale.
- Ogni proposta dedotta per voto, non per segnale diretto, è **incerta** nel report. Regola generale: se il valore viene da una regola statistica e non da un match esplicito, è incerto.
- Lo split nome/cognome sbaglierà sui nomi composti (`Maria Grazia Del Bianco`). Accettato: l'utente lo vede in un secondo e lo corregge, ed è un errore di natura diversa da un'esperienza attribuita all'azienda sbagliata. Il campo è marcato **incerto** quando i token sono più di 2.
- Il **fallback anti-disastro** del ticket 13 (< 2 heading riconosciuti → tutto in "Da rivedere") resta in piedi.

## Testing Decisions

- **Gate della metrica attivo in questa slice**: singola colonna **recall ≥ 85%, precisione ≥ 90%**; multi-colonna **precisione ≥ 90%**, nessun target di recall. Il test fallisce sotto soglia.
- Test dedicati al voto per-documento: ordine azienda-prima, ordine ruolo-prima, documento misto senza maggioranza (→ fallback a vuoto), documento con un solo blocco.
- Test sull'invariante di non-perdita: resta verde anche con le euristiche aggressive.
- Corpus allargato con **CV sintetici** che imitano le famiglie note (export LinkedIn, Europass IT, Word→PDF singola colonna, un due-colonne), per non tarare tutto su un solo documento.

## Out of Scope

- CV multi-colonna con ordine di lettura instabile: nessun target di recall, vale solo la garanzia di non danneggiare (ticket 05).
- LLM o servizi di rete: la decisione è **motore a regole on-device**, confermata in sessione di grilling.

## Further Notes

- Amendment sostanziale al ticket 13: le sezioni "Non tentiamo di riempire automaticamente" e "Ruolo/azienda lasciati vuoti" sono superate. Il ticket va aggiornato con una nota, non riscritto: la motivazione originale era valida sotto il vincolo dell'auto-import puro.
