Fetta verticale #M. Costruisce il **metro** prima del lavoro: harness di cattura fixture dall'estrazione reale, corpus anonimizzato, golden scritti a mano e test che calcola il **tasso di conversione**. Nessun cambiamento visibile all'utente: è l'infrastruttura che rende misurabili le Slice N/O/P. Dipende da: #28 (Import PDF).

## Problem Statement

L'import della Slice I (#28) su un CV reale in formato Europass produce `Esperienze` vuota e l'intero documento riversato in "Da rivedere". Baseline stimata a mano: **recall ~4%, precisione ~18%** su ~47 campi attesi.

Oggi non esiste modo di misurarlo. Le fixture in `test/pdf/pdf_import_heuristics_test.dart` sono **sintetiche**: la helper `page()` costruisce un `PdfCharRect` per riga con altezze inventate (10 corpo / 16 heading), quindi gli heading sono più alti della mediana **per costruzione**. Il proxy geometrico `height >= pageMedian` — su cui poggia tutta la logica section-first — non è mai stato messo alla prova su un documento vero, dove `WORK EXPERIENCE` è in maiuscolo ma probabilmente **non** più alto del corpo.

Senza una metrica, ogni euristica successiva è un'opinione.

## Solution

- **Harness di cattura**: `integration_test/capture_fixtures_test.dart`, eseguito **una tantum a mano** su macOS (non in CI), che apre un PDF reale, esegue la vera estrazione `pdfrx` + `PdfImporter._toPageText`, applica una **mappa di anonimizzazione** e serializza in `test/pdf/fixtures/<nome>.json` la lista di pagine con `{text, height}` per riga.
- **Anonimizzazione strutturale obbligatoria** (il repo è pubblico): ogni valore personale sostituito con uno **della stessa forma**, perché la forma è ciò che le euristiche leggono. La mappa di sostituzione vive in `fixtures/.anonymization_map.json`, **gitignorata**.
- **Corpus**: si parte con 1 CV (Europass, singola colonna, IT/EN misto). Ogni fixture dichiara la propria **famiglia di layout** (`single_column` | `multi_column`) nel JSON.
- **Golden**: per ogni fixture, un `.golden.json` scritto **a mano guardando il PDF**, che descrive il `CvDocument` corretto campo per campo.
- **Test della metrica**: `test/pdf/conversion_rate_test.dart` esegue `buildFromPages` sulla fixture, confronta col golden e calcola recall + precisione, con breakdown per sezione stampato a console.

## User Stories

1. Come sviluppatore, voglio catturare in un JSON committabile l'estrazione reale di un PDF, così i test girano su input veri senza dipendere da PDFium a ogni run.
2. Come sviluppatore, voglio che la cattura anonimizzi **automaticamente** i dati personali, così non posso pubblicare per sbaglio nome, email e telefono su un repo pubblico.
3. Come sviluppatore, voglio che l'anonimizzazione preservi la struttura (numero di token, separatori, prefissi, cifre), così la fixture resta rappresentativa del documento originale.
4. Come sviluppatore, voglio un test che stampi recall e precisione con breakdown per sezione, così vedo **dove** perdo, non solo quanto.
5. Come sviluppatore, voglio che ogni fixture dichiari la famiglia di layout, così i target si applicano per famiglia.
6. Come sviluppatore, voglio un test di invariante che verifichi che **nessuna riga estratta sparisce** (ogni riga finisce in un campo o in "Da rivedere"), così non perdo pezzi di CV in silenzio.

## Implementation Decisions

- **Tasso di conversione** = coppia `(recall, precisione)` sui campi del golden. `recall = campi corretti / campi attesi`. `precisione = campi corretti / campi proposti`. Un campo è "corretto" se uguale al golden dopo normalizzazione (trim, collapse whitespace, case-insensitive per i testi liberi).
- **Denominatore: un campo, un voto.** Nessuna pesatura per sezione: il numero è dominato dalle Esperienze, ed è corretto che lo sia — è lì che sta il lavoro manuale dell'utente. Il breakdown per sezione è **diagnostica**, non obiettivo.
- **La copertura testuale** (% di caratteri fuori da "Da rivedere") si calcola e si stampa, ma **non è un obiettivo**: è banalmente falsificabile (basta buttare tutto il testo in una `descrizione`).
- **Formato fixture**: `{ "layoutFamily": "single_column", "pages": [ { "pageIndex": 0, "lines": [ { "text": "...", "height": 11.2 } ] } ] }`. Deliberatamente vicino a `PdfPageText`/`PdfCharRect` per un mapping banale.
- **La cattura non gira in CI**: `pdfrx` richiede `pdfrxFlutterInitialize` e il native-asset wiring che `flutter test` non fornisce (già documentato nel doc-comment di `pdf_importer.dart`). I test della metrica leggono solo il JSON congelato e restano `dart test` puri, veloci.
- **Rischio accettato**: le fixture congelate non testano più `pdfrx`. Se pdfrx cambia comportamento in una minor, la metrica resta verde e l'app reale peggiora. È la stessa fiducia dichiarata dei ticket 05/10; va ri-catturato se si cambia libreria PDF.

## Testing Decisions

- Test unitari sul serializzatore/deserializzatore delle fixture (round-trip JSON).
- Test unitari sulla funzione di scoring con golden e risultati costruiti a mano: caso perfetto (100/100), caso a zero proposte (recall 0, precisione non definita → convenzione: 100% se non propone nulla di sbagliato, documentata), caso con proposte sbagliate.
- Il test della metrica **non fallisce** su soglia in questa slice: stampa i numeri e registra la baseline. Il gate a 85/90 arriva con la Slice P.
- Test di invariante non-perdita su tutte le fixture del corpus.

## Out of Scope

- Qualsiasi modifica alle euristiche (→ Slice N e P).
- Corpus sintetico multi-famiglia (→ segue subito dopo, stessa slice non necessaria).
- Fedeltà di round-trip (→ Slice Q).

## Further Notes

- Il PDF sorgente **non entra nel repo**, in nessuna forma. Solo il JSON anonimizzato.
- Target di riferimento fissati in sessione di grilling, da applicare come gate nella Slice P: **singola colonna recall ≥ 85%, precisione ≥ 90%**; **multi-colonna: nessun target di recall, precisione ≥ 90%** su ciò che propone. Motivazione multi-colonna: il ticket 05 ha stabilito che l'ordine di lettura estratto è instabile, e nessuna euristica testuale lo ricompone in modo affidabile.
- Glossario dei termini (`Corpus reale`, `Fixture di estrazione`, `Golden`, `Tasso di conversione`, `Famiglia di layout`) in `CONTEXT.md`.
