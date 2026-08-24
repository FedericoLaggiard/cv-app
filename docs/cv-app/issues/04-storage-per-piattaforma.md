# Layer di storage per piattaforma

Type: grilling
Status: closed
Blocked by: 03

## Question

Definire il **layer di persistenza astratto** e come si concretizza sulle tre piattaforme, mantenendo un'unica logica applicativa sopra.

Punti da chiudere:
- Interfaccia astratta (es. `CvRepository`): quali operazioni espone (list, load, save, rename, delete, duplicate)?
- Desktop/mobile: dove vivono i file di default? Cartella app-managed (path_provider) o cartella scelta dall'utente? Come cambia tra macOS/Windows/Linux/Android/iOS?
- Web: mapping su IndexedDB — una entry per variante, chiavi, indici. Come si gestiscono import/export manuale (download del file JSON, upload)?
- Convenzione di naming file / directory (una cartella con tutte le varianti? un file per variante?).
- Concorrenza / locking (l'utente apre due volte lo stesso CV? l'app è multi-finestra?).
- Backup e recovery: cosa succede se un file è corrotto?

Output atteso: descrizione dell'interfaccia + tabella di mapping per piattaforma.

## Risoluzione

### Modello

- **Library-based** su tutte le piattaforme. L'app gestisce una libreria locale di varianti; l'utente non manipola file per l'uso quotidiano. Il file `.cvapp` è il **canale di portabilità** (import/export), non l'unità di storage manipolata dall'utente.
- **Nessuna sincronizzazione tra dispositivi** (v2, vedi mappa "Fuori scope"). Ogni installazione ha una libreria locale indipendente; il trasferimento cross-device passa per export/import manuale.

### Location fisica della libreria

Cartella **app-managed nascosta** ovunque, coerente cross-piattaforma:

| Piattaforma | Percorso |
| --- | --- |
| macOS | `~/Library/Application Support/<bundleId>/library/` |
| Windows | `%APPDATA%\<appId>\library\` |
| Linux | `~/.local/share/<appId>/library/` |
| iOS | `getApplicationDocumentsDirectory()` (sandbox app, invisibile all'utente) |
| Android | `getApplicationDocumentsDirectory()` (privato all'app) |
| Web | IndexedDB (vedi sotto) |

Su desktop/mobile la cartella è risolta via `path_provider`. Nessuna cartella scelta dall'utente al primo avvio, nessuna cartella dentro "Documenti" visibili. Motivazione: (1) uniforma il modello su 5 piattaforme; (2) elimina la possibilità che l'utente metta la libreria in una cartella cloud-sync (iCloud/Dropbox/OneDrive) creando problemi di edit concorrenti che l'MVP non gestisce.

### Naming dei file dentro la libreria

- Su desktop/mobile: **`<uuid>.cvapp`** (l'`id` UUID del CV, deciso in [ticket 03](03-formato-file-cv.md)).
- Su web: chiave IndexedDB = `id` UUID.

Il nome file non riflette il `variantName` scelto dall'utente: cambiare `variantName` è una modifica di un campo dentro il JSON, senza side-effect sul filesystem (niente rename atomici, niente sanitizzazione di caratteri illegali, niente risoluzione di collisioni).

Su **export**, il dialog di save-as propone come default `<variantName sanitizzato>.cvapp` (regola della `03`), quindi l'utente ottiene comunque nomi umani nei file che escono dall'app.

### Layout web (IndexedDB)

- Nome DB: `cvapp`.
- Un solo object store: `variants`.
- **Key**: `id` UUID (stringa).
- **Value**: l'oggetto CV completo — stesso schema del file `.cvapp` (compresi `assets` in base64). IndexedDB serializza con structured clone; nessuna conversione ai bordi.
- **Index**: `by_updatedAt` su `value.updatedAt`, per la lista "recenti" ordinata senza scan lineare.

Nessun object store separato per gli asset binari. Un solo modello mentale "una variante = un oggetto atomico", identico al file su disco.

### Auto-save e write

- **Auto-save** con debounce **~800ms** dopo l'ultima modifica dell'utente. Nessun pulsante "Salva", nessun dialog "vuoi salvare?" alla chiusura.
- Su desktop/mobile: scrittura **atomica via tmp+rename** (`<uuid>.cvapp.tmp` → `rename()` su `<uuid>.cvapp`), per evitare file troncati in caso di crash a metà scrittura.
- Su web: la transazione IndexedDB è già atomica.
- `updatedAt` è ricalcolato a ogni save.

Undo/redo nell'editor (ticket `07`) è la primary safety net contro l'errore umano; il "chiudi senza salvare" del modello classico non esiste.

### Concorrenza

**Nessun controllo** — last-write-wins. Motivazioni:
- Su web non c'è modo affidabile di prevenire tab multipli.
- Su desktop non implementiamo single-instance né lock file nell'MVP.
- Cross-device concurrency non esiste per costruzione (niente sync).

Costo accettato: se l'utente apre la stessa variante due volte in parallelo e modifica entrambe, l'ultimo save vince silenziosamente. Documentato nella spec come limite noto dell'MVP.

### File corrotto / illeggibile

- All'apertura, se il JSON è malformato o fallisce la validazione strict (campi sconosciuti, `schemaVersion` non gestibile, ecc.), la variante compare nella lista con badge **"⚠ corrotta"** e non è apribile in editor.
- Azioni disponibili sulla riga corrotta: **"Esporta file grezzo"** (restituisce i bytes originali per riparazione manuale fuori dall'app e successivo reimport) e **"Elimina"**.
- **Nessun backup automatico** nell'MVP. Il canale di backup consigliato all'utente è l'export periodico del `.cvapp` verso il suo cloud/HD di scelta.

### Interfaccia astratta `CvRepository`

Ibrida `Stream` per le viste reattive + `Future` per le azioni one-shot:

```dart
abstract class CvRepository {
  // Viste reattive (si aggiornano automaticamente dopo ogni save/delete/import)
  Stream<List<VariantSummary>> watchAll();
  Stream<CvDocument> watch(String id);

  // Azioni one-shot
  Future<CvDocument> create({String? initialVariantName});
  Future<CvDocument> duplicate(String id);
  Future<void> save(CvDocument doc);          // usata dall'auto-save
  Future<void> delete(String id);

  // Bordo verso il mondo esterno: solo bytes
  Future<ImportResult> importFromBytes(Uint8List bytes);
  Future<Uint8List> exportToBytes(String id);
}

class VariantSummary {
  final String id;
  final String variantName;
  final DateTime updatedAt;
  // eventualmente: presenza foto profilo, numero sezioni, ecc.
}

sealed class ImportResult {
  const ImportResult();
}
class ImportSuccess extends ImportResult { final CvDocument doc; }
class ImportConflict extends ImportResult {
  final String existingId;
  final CvDocument incoming;   // già parsato ma non ancora scritto in libreria
}
class ImportCorrupt extends ImportResult { final String reason; }
```

Regole:
- **`Uint8List` è il solo contratto** con il mondo esterno. File picker, save dialog, download browser, share sheet, file association OS **vivono sopra il repository**, non dentro.
- **Nessun `rename`** esplicito. Cambiare `variantName` è un normale `save()` con il campo modificato dentro il `CvDocument`.
- **`ImportConflict`** comunica al layer sopra che l'`id` in ingresso esiste già in libreria. Il layer chiede all'utente "sovrascrivi vs importa come nuova variante (rigenera `id`)" (regola della `03`) e richiama `save()` con il documento risolto.
- **`ImportCorrupt`** è restituito quando il parsing/validazione fallisce (JSON malformato, `schemaVersion` futura, campi sconosciuti). Nessuna scrittura in libreria.

Su web l'implementazione mantiene internamente un `StreamController` per object store; ogni `save()`/`delete()`/`importFromBytes()` fa emettere il nuovo stato agli osservatori attivi.

### Doppio-click / share-in di un `.cvapp` esterno

- Su desktop: file association per `.cvapp`. Doppio-click ⇒ l'app si avvia (o riceve un evento di apertura file se già aperta) e riceve i bytes.
- Su iOS/Android: dichiarazione delle capability per aprire `.cvapp` via share sheet / `openURL` / `Intent`. L'utente sceglie "Apri con CV app" e l'app riceve i bytes.
- **Auto-import silenzioso** nella libreria via `importFromBytes()`, poi apre l'editor sulla nuova variante importata. Toast non modale: "Variante *`<variantName>`* aggiunta alla libreria. [Annulla]".
- Se `importFromBytes()` restituisce `ImportConflict`, il flow interattivo "sovrascrivi vs importa come nuovo" resta invariato (deciso in `03`).

Coerente con la scelta library-based: dentro l'app non esiste uno stato "aperto ma non in libreria".

### Vincoli trasversali

- **State management**: `flutter_bloc` (Bloc + Cubit). I `Stream<>` esposti dal repository si legano a `Cubit` con `emit()` sul nuovo stato. Vincolo pinnato nella mappa; il [ticket 06](06-scelta-stack-flutter.md) è stato ridotto di scope di conseguenza.
- **Portabilità del file**: il repository non manipola metadati OS-specifici (mtime, permessi, xattr). Un `.cvapp` esportato è autocontenuto (regola della `03`).

### Intersezioni con altri ticket

- **Ticket 06 (scelta stack)** — pacchetto Dart per IndexedDB (`idb_shim` vs `sembast_web`) da valutare qui; state management già chiuso; file picker come input di `Uint8List`.
- **Ticket 07 (UX editor)** — auto-save + undo/redo sono decisioni che influenzano l'editor (nessun "Salva" nel menu, undo profondo per non perdere lavoro).
- **Ticket 09 (foto e asset)** — ora sbloccato. L'asset store per-variante deciso in `03` vive dentro il JSON come `{"assetId": {mimeType, data}}`; qui abbiamo confermato che anche in IndexedDB restano base64 dentro l'oggetto della variante.
- **Post-MVP**: sync tra dispositivi, backup automatico, edit concorrenti, single-instance desktop.
