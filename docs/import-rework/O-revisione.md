Fetta verticale #O. Introduce il **passo di revisione** dell'import — versione leggera del ticket 11, senza visore PDF affiancato — e il seam `ImportProposalReport` che porta la confidence delle proposte. È il cambio di rotta che rende **sicure** le euristiche aggressive della Slice P. Dipende da: #28, Slice N. Decisione registrata in `docs/adr/0002-import-proposal-report.md`.

## Problem Statement

Il ticket 10 ha scelto **auto-import puro**: nessuna UX di revisione, l'editor normale è l'unica superficie di correzione. Il ticket 11 (import assistito) è stato chiuso "fuori scope MVP" **come conseguenza** di quella scelta.

La prova sul campo dice che non regge. E la ricerca lo aveva previsto: il ticket 05 concludeva testualmente *"Auto-mapping completo eliminato... Strategia MVP = import assistito, non auto-import"*. Il ticket 10 ha scavalcato la raccomandazione dell'analista; la Slice I l'ha implementata; il risultato su un CV reale è inutilizzabile.

Senza un umano nel loop, ogni euristica è costretta alla filosofia conservativa del ticket 13 ("un campo vuoto è meglio di un campo sbagliato"), perché un errore finisce silenziosamente in un CV salvato. **È questa costrizione a tenere il recall a zero**, non la difficoltà tecnica.

## Solution

- `PdfImporter.import` restituisce, insieme al `CvDocument`, un **`ImportProposalReport`** transiente: per ogni campo proposto, il livello di certezza (**binario**: certo / incerto) e le righe del PDF di provenienza.
- Dopo l'import, invece di aprire direttamente l'editor, si apre il **passo di revisione**: una schermata che mostra *cosa ha capito* l'import — "5 esperienze, 1 formazione, 12 skill, 2 lingue" — con i campi **incerti evidenziati**.
- L'utente conferma in blocco o corregge inline. Alla conferma il `CvDocument` viene salvato come nuova variante e il report **buttato via**.
- "Da rivedere" resta nella schermata come **pannello sorgente**: le righe non attribuite si possono assegnare a un campo da lì.
- Nessun rendering del PDF affiancato: è la parte costosa del ticket 11 e su mobile lo split-view a tre pannelli è impraticabile (lo dice il ticket 11 stesso). La schermata di questa slice **è** il pannello destro dell'eventuale wizard completo, quindi A resta raggiungibile per aggiunta, non per riscrittura.

## User Stories

1. Come utente che importa un PDF, voglio vedere un riepilogo di cosa l'app ha capito prima che venga salvato, così non mi ritrovo una variante piena di roba sbagliata.
2. Come utente, voglio che i campi di cui l'app **non è sicura** siano evidenziati, così guardo 5 campi invece di 40.
3. Come utente, voglio confermare tutto con un gesto se il risultato è giusto, così l'import resta veloce quando funziona.
4. Come utente, voglio correggere un campo direttamente nella schermata di revisione, senza passare dall'editor.
5. Come utente, voglio vedere il testo rimasto in "Da rivedere" nella stessa schermata e poterlo assegnare a un campo, così recupero quello che l'import non ha capito.
6. Come utente, voglio poter annullare la revisione senza creare la variante, così un import sbagliato non mi sporca la libreria.
7. Come utente, **non** voglio vedere punteggi numerici di confidenza: voglio solo sapere dove guardare.

## Implementation Decisions

- **La confidence non entra nel `CvDocument`.** Il documento è il modello persistito, serializzato in `.cvapp` da `json_codec.dart` (ticket 03). Aggiungerci uno stato per campo significherebbe versionare il formato file e persistere per sempre un dato che vive 30 secondi — e che dopo la prima modifica manuale sarebbe comunque falso. Vedi ADR 0002.
- **Naming**: classe `ImportProposalReport` (PascalCase per `camel_case_types`); `importProposalReport` per istanze e parametri.
- **Confidence binaria**, mai numerica. Questa parte del ticket 13 ("nessun confidence score visibile all'utente") resta valida anche dopo che ne abbiamo ribaltata metà.
- **Il report è legato alla sessione**: se l'utente chiude l'app durante la revisione, la confidence è persa e alla riapertura vede un CV normale. Accettato: revisione più lenta in un caso raro, nessuna perdita di dati.
- `ImportOutcome.filled` cambia forma per portare la coppia. L'unico chiamante è `pdf_import_flow.dart`.
- **Mobile-first sul layout**: lista verticale a sezioni, non split-view. Su desktop la stessa lista con larghezza massima.

## Testing Decisions

- Unit test su `ImportProposalReport`: costruzione, marcatura certo/incerto, provenienza righe.
- Widget test: campi incerti evidenziati; conferma → variante creata; annulla → nessuna variante; assegnazione di una riga da "Da rivedere" a un campo.
- Test che verifica che il `.cvapp` scritto dopo la conferma sia **identico** a quello che si otterrebbe compilando gli stessi campi a mano: nessuna traccia del report su disco, nessun campo nuovo nel formato.

## Out of Scope

- Visore PDF affiancato e drag&drop (→ ticket 11 completo, v2).
- Euristiche aggressive (→ Slice P: questa slice le **abilita**, non le implementa).
- OCR (→ v2, ticket 12).

## Further Notes

- Amendment esplicito ai ticket 10, 11 e 13. Il ticket 11 va riaperto e riclassificato da "v2" a "MVP, versione leggera".
