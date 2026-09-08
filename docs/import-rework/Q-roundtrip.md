Fetta verticale #Q. Aggiunge la **fedeltà di round-trip** come gate di non-regressione: l'app deve saper rileggere i PDF che essa stessa produce. Corpus infinito e gratuito, generabile a comando. Dipende da: Slice M (infrastruttura metrica), Slice P (euristiche a target).

## Problem Statement

Il corpus reale è piccolo e costa lavoro manuale: ogni CV richiede un golden scritto a mano. Serve un secondo segnale, economico e illimitato, che protegga dalle regressioni tra un rilascio e l'altro.

I template di export sono la fonte naturale: l'app genera PDF di cui conosce esattamente il contenuto. Un import che non sa rileggere l'output del proprio export è rotto in modo evidente.

## Solution

- Generare PDF dai tre template (Classico, Moderno, Minimal) a partire da `CvDocument` costruiti nei test, in **entrambe le lingue** delle label (`LabelLocale.it` / `.en`).
- Ri-importarli e confrontare il risultato con la **proiezione attesa** del documento sorgente.
- Il confronto gira come test e **fallisce** su regressione.

## User Stories

1. Come sviluppatore, voglio sapere subito se una modifica a un template rompe l'import, così non lo scopro da una segnalazione utente.
2. Come sviluppatore, voglio che il gate copra IT ed EN, così il dizionario titoli e i marker di data restano allineati alle label che l'app stampa davvero.

## Implementation Decisions

- **La fedeltà di round-trip non è il tasso di conversione.** Sono due metriche distinte e non si sostituiscono: la fedeltà può stare al 95% mentre la conversione sul mondo reale sta al 30% (è più o meno la situazione di partenza). Il gate di rilascio resta il tasso di conversione sul corpus reale.
- **Trappola nota da evitare: il sovra-adattamento.** I tre template sono tre punti in uno spazio di layout enorme, e sono l'unico corpus di cui controlliamo entrambi i lati. Ottimizzare le euristiche *su questo numero* produce un import che legge benissimo i PDF prodotti da noi e male i CV veri. **Per questo la slice arriva dopo la P e mai prima**: il corpus reale fissa la direzione, il round-trip protegge dalle regressioni.
- **Il round-trip è lossy per costruzione**: il PDF non contiene gli `id` UUID, non contiene la `foto` (`AssetRef`), il Markdown di `descrizione` viene reso come glifi (grassetti e liste diventano testo piano), Minimal **ignora la foto per design**, e i tre template non stampano gli stessi campi. L'atteso **non è** il `CvDocument` sorgente: è una sua **proiezione**, che va definita esplicitamente per template.
- **Copertura garantita dalle label**: i template rendono gli heading via `SharedTemplateLabels` (`esperienze`, `formazione`, `skill`, `lingue`, `certificazioni`) e le date via `intl` con `it_IT`/`en_US`, marker `presente`/`present` inclusi. Il round-trip verifica quindi automaticamente che dizionario e parser date coprano **almeno** l'output dei nostri template in entrambe le lingue.

## Testing Decisions

- 3 template × 2 lingue = 6 casi minimi, su un `CvDocument` di riferimento che tocca tutte le sezioni.
- La proiezione attesa per template è codificata e commentata: ogni campo escluso va giustificato in una riga.
- Il gate misura la fedeltà su **campi proiettati**, non su tutti i campi del documento sorgente.

## Out of Scope

- Sostituire il corpus reale (→ non accadrà: sono metriche diverse).
- Confronto pixel-perfect del PDF renderizzato (è un test di export, non di import).

## Further Notes

- Se un giorno si cambia libreria PDF, questo gate è il primo segnale che qualcosa si è mosso sotto.
