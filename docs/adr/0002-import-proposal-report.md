# ADR 0002 — La confidence dell'import vive in `ImportProposalReport`, non nel `CvDocument`

Stato: accettata. Amendment ai ticket 10 (auto-import puro), 11 (import
assistito → v2) e 13 (euristiche conservative).

## Contesto

L'import automatico del ticket 28 si è dimostrato inadeguato su CV reali:
su un CV in formato Europass con 5 esperienze regolari, il risultato è
`Esperienze` vuota e l'intero documento riversato nella sezione custom
"Da rivedere". Le cause sono in parte guasti (formati data non coperti,
dizionario titoli incompleto), in parte la filosofia dichiarata del ticket
13 ("precisione > recall": `ruolo`, `azienda`, `titolo`, `istituto`,
`nome`, `cognome` non vengono **mai** compilati).

Da questa evidenza discendono due cambi di rotta, decisi in sessione di
grilling:

1. Si anticipa in fase uno un **passo di revisione** dell'import — versione
   leggera del ticket 11, senza il visore PDF affiancato. Questo riporta il
   progetto alla raccomandazione originale del ticket 05 ("import
   assistito, non auto-import"), che il ticket 10 aveva scavalcato.
2. Con l'umano nel loop, le euristiche diventano **aggressive**: propongono
   un valore per ogni campo dove esiste un candidato plausibile, inclusi
   quelli che il ticket 13 vietava.

Le euristiche sanno quanto sono sicure di ogni proposta (una data parsata
con successo è certa; un `ruolo` dedotto da un voto di maggioranza sul
documento no). La schermata di revisione deve usare quell'informazione per
evidenziare i campi incerti — altrimenti l'utente deve rileggere ogni campo
e il passo di revisione non fa risparmiare nulla. Serve quindi un posto
dove metterla.

## Decisione

La confidence e la provenienza delle proposte **non entrano nel
`CvDocument`**. L'import restituisce una coppia: il `CvDocument` di sempre,
più un `ImportProposalReport` transiente che porta, per ogni campo
proposto, il livello di certezza (binario: certo / incerto) e le righe del
PDF da cui la proposta deriva.

La schermata di revisione consuma il report; alla conferma dell'utente il
report viene scartato e su disco finisce solo il `CvDocument`.

Nota di naming: la classe Dart è `ImportProposalReport` (PascalCase, per
`camel_case_types`); `importProposalReport` è il nome delle istanze e dei
parametri.

## Conseguenze

- Il **formato file `.cvapp` non cambia**: nessuna migrazione, nessun
  campo di versione da alzare, nessuna modifica a `json_codec.dart`
  (ticket 03).
- Un CV salvato non porta con sé per sempre uno stato "questo campo era
  incerto all'import di due anni fa", che dopo la prima modifica manuale
  sarebbe comunque falso.
- Il report è **legato alla sessione di import**: se l'utente chiude
  l'app durante la revisione, l'informazione di confidence è persa e alla
  riapertura vede un CV normale con campi pieni. Accettato: il costo è una
  revisione più lenta in un caso raro, non una perdita di dati.
- La `PdfImporter.import` cambia firma (non restituisce più solo un
  `ImportOutcome` con dentro il documento). L'unico chiamante è
  `pdf_import_flow.dart`.
- Resta valida la parte del ticket 13 che vieta di **mostrare un punteggio
  numerico** all'utente: il livello è binario e si traduce in
  un'evidenziazione visiva, non in una percentuale.

## Alternative scartate

- **Confidence dentro il `CvDocument`** (es. un campo di stato per
  campo): richiede di versionare il formato file e di persistere per
  sempre un dato che vive 30 secondi.
- **Nessuna confidence, tutte le proposte uguali**: la revisione
  diventerebbe un modulo di 40 campi da rileggere per intero, cioè
  esattamente il costo che il passo di revisione deve eliminare.
- **Punteggio numerico visibile**: un valore non calibrato è peggio di
  nessun valore; già escluso dal ticket 13 e la ragione regge ancora.
