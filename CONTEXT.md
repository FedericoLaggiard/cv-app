# CV app

App Flutter per creare, mantenere ed esportare curriculum, con più varianti per candidatura e import di CV esistenti in PDF. Nessun backend: tutto on-device.

## Language

### Documento

**Variante**:
Una versione nominata e indipendente di un CV, salvata come file a sé.
_Avoid_: Versione, revisione, branch

**Sezione fissa**:
Una sezione dallo schema tipizzato, identificata da un `kind` immutabile.
_Avoid_: Sezione standard, sezione predefinita

**Sezione custom**:
Una sezione aggiuntiva composta da un titolo e un blob Markdown libero.
_Avoid_: Sezione libera, sezione extra

**Da rivedere**:
La sezione custom che raccoglie il testo che l'import non ha saputo attribuire a nessun campo.
_Avoid_: Scarti, leftover, residuo

### Import

**Import automatico**:
La conversione di un PDF esistente in una variante, senza passaggi di conferma da parte dell'utente.
_Avoid_: Import assistito (è un'altra cosa: prevede conferma umana, rinviata a v2)

**Proposta**:
Un valore che l'import suggerisce per un campo, in attesa di conferma umana. Ogni proposta è certa o incerta; l'utente vede la differenza, non un punteggio.
_Avoid_: Suggerimento, candidato, guess

**Passo di revisione**:
La schermata che mostra le proposte dell'import e le fa confermare o correggere prima di salvare la variante.
_Avoid_: Wizard, anteprima, conferma

**Corpus reale**:
L'insieme di CV veri, non prodotti da questa app, usati per misurare la qualità dell'import.
_Avoid_: Dataset, campione

**Fixture di estrazione**:
Il testo e la geometria estratti una volta sola da un PDF del corpus e congelati su file, usati come input dei test.
_Avoid_: Snapshot, dump

**Famiglia di layout**:
La classe strutturale di un CV — singola colonna o multi-colonna — dichiarata per ogni CV del corpus. Le due famiglie hanno obiettivi di conversione diversi, perché sui multi-colonna l'ordine di lettura estratto è instabile.
_Avoid_: Tipo di CV, template, formato

**Golden**:
Il risultato che l'import dovrebbe produrre per una fixture, scritto a mano guardando il PDF originale.
_Avoid_: Atteso, expected, verità

**Tasso di conversione**:
Quanto l'import riempie correttamente i campi del golden sul corpus reale, espresso come coppia recall + precisione.
_Avoid_: Accuratezza, percentuale di successo, copertura

**Fedeltà di round-trip**:
Quanto l'import sa rileggere un PDF prodotto dall'export di questa stessa app. È una proprietà distinta dal tasso di conversione e non lo sostituisce.
_Avoid_: Round-trip accuracy, andata e ritorno
