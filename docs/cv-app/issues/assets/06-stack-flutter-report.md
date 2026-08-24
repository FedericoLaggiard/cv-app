# Stack Flutter per CV App MVP — Ricerca sulle Librerie Chiave

> Data ricerca: 2026-08-23
> Versioni verificate su pub.dev via API `pub.dev/api/packages/<nome>`.
> Libreria di import PDF (`pdfrx`) già scelta in precedenza — non rivalutata in questo report.

---

## Executive Summary

Dopo la verifica su pub.dev (2026-08-23), lo stack Flutter MVP per l'app CV cross-platform (mobile + desktop + web) più solido e interamente open-source risulta il seguente.

**Routing**: `go_router` v17.5.0 (Flutter team, BSD-3-Clause) è la scelta naturale — feature-complete, deep linking nativo, nessun code-gen necessario, sintassi URL-based chiara per ~10 route.

**PDF export**: la combo `pdf` v3.13.0 + `printing` v5.15.0 (David PHAM-VAN, Apache-2.0) è la soluzione consolidata e cross-platform vera (Android, iOS, macOS, Windows, Linux, Web). `pdf` genera documenti con un widget-system simil-Flutter; `printing` gestisce la consegna all'utente tramite `Printing.sharePdf()` su mobile e `savePdf()` su desktop/web.

**File picker**: `file_picker` v12.0.0 (Miguel Ruivo, MIT) copre tutte e 6 le piattaforme incluso Web/WASM, ha `pickFiles()` che restituisce `Uint8List` via `readAsBytes()`, e include anche `saveFile()` — tutto in un unico pacchetto federated.

**Save/share export**: su mobile `share_plus` v13.3.0 (FlutterCommunity, BSD-3-Clause) è il più maturo; su desktop e Web il `saveFile()` di `file_picker` gestisce il dialog di salvataggio; su Web `share_plus` ha fallback download automatico. La combinazione `share_plus` + `file_picker.saveFile()` copre tutti i target senza dipendenze custom su `dart:html`.

**Storage Web (IndexedDB)**: `idb_shim` v2.9.7+1 (tekartik / Alexandre Roux, BSD-3-Clause) è l'astrazione più diretta e leggera sopra IndexedDB nativo; espone esattamente il modello "un object store, key UUID, value JSON blob" con API asincrona standard e compatibilità WASM via `dart:js_interop`.

**Serializzazione JSON**: la combo `freezed` v4.0.0 + `json_serializable` v6.14.1 + `freezed_annotation` v3.1.0 è lo standard de-facto della comunità Bloc; genera classi immutabili con `copyWith`, `==`, `hashCode`, `toJson`/`fromJson`. `dart_mappable` v4.8.0 è un'alternativa moderna valida soprattutto per chi vuole evitare il pattern `part`, ma è meno integrata nell'ecosistema Bloc.

**Markdown editor**: ⚠️ `flutter_markdown` è stato **marcato come discontinued** su pub.dev e sostituito da `flutter_markdown_plus` v1.0.12 (MIT). Per il solo rendering usare `flutter_markdown_plus`. Per l'editing, la scelta più ricca è `appflowy_editor` v6.2.0 (cross-platform totale), ma la sua licenza è **AGPL-3.0** — incompatibile con app closed-source. Se AGPL non è accettabile, `super_editor` (MIT, attivo su GitHub ma releases rade su pub.dev) è il piano B; per un MVP leggero, un `TextField` nativo con toolbar custom + `flutter_markdown_plus` per la preview è sufficiente.

**State management** (`flutter_bloc` v9.1.1, MIT, Felix Angelov): Dart puro, cross-platform totale, ecosistema maturo, integrazione nativa con modelli immutabili `freezed`. Confermato senza rivalutazione.

---

## 1. Routing

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme (mobile/desktop/web) | Stato manutenzione | Note |
|---|---|---|---|---|---|---|
| [`go_router`](https://pub.dev/packages/go_router) | Flutter team (flutter.dev) | `17.5.0` — 2026-08-10 | BSD-3-Clause | ✅ Android, iOS, Windows, macOS, Linux, Web | Feature-complete; bug-fix attivo | Router ufficiale Flutter. Deep linking nativo. Nessun code-gen. `ShellRoute` per layout con bottom nav o sidebar persistente. Sintassi URL template (`/cv/:id`). |
| [`auto_route`](https://pub.dev/packages/auto_route) | Milad Akarie | `11.1.0` — 2025-12-16 | MIT | ✅ Android, iOS, Windows, macOS, Linux, Web | Attiva | Fortemente tipizzato via code-gen (`build_runner`). Route e argomenti generati automaticamente. Più boilerplate iniziale rispetto a `go_router`. |
| [`beamer`](https://pub.dev/packages/beamer) | Sandro Lovnički | `1.7.0` — 2024-10-08 | MIT | ✅ Android, iOS, Windows, macOS, Linux, Web | Moderata (ultima release ~10 mesi prima della data di ricerca) | Buono per navigazione profondamente annidata. API `beamToNamed`. Meno aggiornato rispetto a `go_router`; manutenzione rallentata. |

### Raccomandazione

**Scelta: `go_router` v17.5.0.** Mantenuto direttamente dal Flutter team, nessun code-gen richiesto, deep linking funzionante su tutte le piattaforme incluso Web URL-based. Per 5–10 route con possibili schermi annidati (`ShellRoute` per layout con sidebar/bottom bar), è la soluzione a più basso rischio e massima longevità.

**Piano B**: `auto_route` se si preferisce la tipizzazione forte degli argomenti e si accetta il code-gen via `build_runner`. `beamer` non è raccomandato per nuovi progetti per via della manutenzione più lenta.

---

## 2. PDF Export (solo generazione, non import)

> ⚠️ `pdfrx` è già scelto per l'**import** PDF (MIT, cross-platform). Questa sezione riguarda esclusivamente la **generazione** di PDF da dati/widget Flutter.
> Syncfusion `syncfusion_flutter_pdf` e Apryse/PDFtron: **escluse per policy licenza** (licenza commerciale/proprietaria).

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme (mobile/desktop/web) | Stato manutenzione | Note |
|---|---|---|---|---|---|---|
| [`pdf`](https://pub.dev/packages/pdf) | David PHAM-VAN (DavBfr) | `3.13.0` — 2026-06-16 | Apache-2.0 | ✅ Dart puro: Android, iOS, Windows, macOS, Linux, Web (nessun plugin nativo per la generazione) | Molto attiva | Genera PDF completo con widget-system simil-Flutter: `pw.Text`, `pw.Column`, `pw.Table`, font TrueType, immagini, SVG. Demo interattiva su web. Nessuna dipendenza nativa. |
| [`printing`](https://pub.dev/packages/printing) | David PHAM-VAN (DavBfr) | `5.15.0` — 2026-06-16 | Apache-2.0 | ✅ Android, iOS, Windows, macOS, Linux, Web | Molto attiva | Companion plugin di `pdf`. Espone: `Printing.sharePdf()` (mobile share sheet), `Printing.layoutPdf()` (stampa nativa OS), `Printing.savePdf()` (desktop/web). Su Web usa PDF.js per preview; su Windows/Linux usa PDFium (scaricato automaticamente). |
| [`htmltopdfwidgets`](https://pub.dev/packages/htmltopdfwidgets) | vanhoecke | versione non recente verificata | MIT | Dart puro | Bassa | Converte HTML in widget `pdf`. Utile se si usa HTML come formato intermedio. Non sostituisce `pdf`; è una dependency opzionale già citata nella README di `printing`. |
| Syncfusion `syncfusion_flutter_pdf` | Syncfusion | — | **Commerciale / Community License** | — | — | **Esclusa per policy licenza.** Non elencare come candidata. |

### Note operative

- La generazione del PDF avviene interamente in Dart (`pdf` package), senza plugin nativi. Il risultato è un `Uint8List` che `printing` consegna all'utente.
- Font personalizzati (es. per CV con tipografia): caricare i file `.ttf` dagli asset Flutter con `fontFromAssetBundle('assets/fonts/Roboto.ttf')`.
- Per il template del CV, la struttura consigliata è: `pw.Document` → `pw.MultiPage` → colonne/righe con `pw.Row`, `pw.Column`, `pw.Table` per sezioni esperienze/formazione.

### Raccomandazione

**Scelta: `pdf` v3.13.0 + `printing` v5.15.0.** Stesso autore, stesso repository, rilasci sincronizzati (entrambi il 2026-06-16). `pdf` genera il documento con il widget-system Dart; `printing` gestisce la consegna all'utente su tutte le piattaforme. È la combo più usata nell'ecosistema Flutter per PDF cross-platform, licenza Apache-2.0, zero dipendenze native per la generazione.

**Piano B**: nessuna alternativa permissiva equivalente trovata per la generazione cross-platform totale. Se si necessita di un approccio HTML→PDF, `htmltopdfwidgets` + `printing` è documentato nella stessa README di `printing`.

---

## 3. File Picker (import PDF)

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme (mobile/desktop/web) | Stato manutenzione | Note |
|---|---|---|---|---|---|---|
| [`file_picker`](https://pub.dev/packages/file_picker) | Miguel Ruivo | `12.0.0` — 2026-08-14 | MIT | ✅ Android, iOS, Linux, macOS, Windows, Web (WASM dichiarato esplicitamente) | Molto attiva | v12: architettura federated. `pickFiles()` → `List<PlatformFile>`. Byte access: `await file.readAsBytes()` → `Uint8List`. Include `saveFile()`. Filtro per estensione (`.pdf`). Cloud files (GDrive, Dropbox, iCloud) su mobile. |
| [`file_selector`](https://pub.dev/packages/file_selector) | Flutter team (flutter.dev) | `1.1.0` — 2025-11-21 | BSD-3-Clause | ✅ Android, iOS, Linux, macOS, Windows, Web — ma `getSaveLocation()` **non disponibile su Android, iOS, Web** | Attiva | Plugin ufficiale Flutter. API `openFile()` / `getSaveLocation()`. Più minimale di `file_picker`. Per il solo open copre tutti i target; per save: solo desktop (Linux, macOS, Windows). |

### Note operative

- **Web**: `file_picker` usa l'input HTML `<input type="file">` come fallback e supporta WASM (dichiarato in README v12). I byte sono accessibili via `readAsBytes()` direttamente senza path fisico.
- **macOS**: richiede entitlement `com.apple.security.files.user-selected.read-only` (o `read-write`) nel file `.entitlements`.
- **UX differenze**: `file_picker` usa dialog nativi su tutti i desktop (GTK su Linux, Win32 su Windows, AppKit su macOS). Su mobile entrambi usano il picker nativo del sistema operativo.
- **Filtro PDF**: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'])` — funziona su tutti i target.

### Raccomandazione

**Scelta: `file_picker` v12.0.0.** Unico pacchetto che copre tutte e 6 le piattaforme dichiarate incluso Web/WASM, restituisce `Uint8List` direttamente, e include già `saveFile()` (utile anche per l'area 4). Attività di manutenzione alta; architettura federated v12 ben strutturata.

**Piano B**: `file_selector` (Flutter team) se si preferisce il pacchetto ufficiale Flutter e si accetta di gestire il save separatamente (solo desktop) tramite un altro meccanismo su mobile/web.

---

## 4. Save/Share/Download di file esportati

> Il file esportato è `Uint8List` (risultato di `doc.save()` del package `pdf`).

### Analisi per piattaforma

| Scenario | Libreria | Meccanismo |
|---|---|---|
| **Mobile** (Android/iOS) | `share_plus` | `SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/pdf')], fileNameOverrides: ['cv.pdf']))` → share sheet nativo |
| **Desktop** (Windows/macOS/Linux) | `file_picker` | `FilePicker.platform.saveFile(fileName: 'cv.pdf', ...)` → dialog nativo "Salva con nome" → poi `File(path).writeAsBytes(bytes)` |
| **Web** | `share_plus` | Tenta Web Share API (Chrome mobile, Safari); fallback automatico a download `<a href download>` su browser desktop |

### Tabella comparativa pacchetti

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme | Stato manutenzione | Note |
|---|---|---|---|---|---|---|
| [`share_plus`](https://pub.dev/packages/share_plus) | FlutterCommunity (plus_plugins) | `13.3.0` — 2026-07-23 | BSD-3-Clause | ✅ Android, iOS, macOS, Windows, Web (Web Share API + download fallback); ⚠️ Linux: **file sharing non supportato** (solo testo/URI via mailto) | Molto attiva | `XFile.fromData()` per bytes in-memory senza file su disco. Flutter Favorite. Configurabile: `downloadFallbackEnabled`. |
| [`file_picker`](https://pub.dev/packages/file_picker) | Miguel Ruivo | `12.0.0` — 2026-08-14 | MIT | ✅ `saveFile()` su Android, iOS, Linux, macOS, Windows, Web | Molto attiva | `saveFile()` restituisce il path scelto; poi scrittura byte con `dart:io` (native) o download (web). |

### Strategia raccomandata (combinazione)

```dart
// Mobile (Android/iOS) e Web:
await SharePlus.instance.share(ShareParams(
  files: [XFile.fromData(pdfBytes, mimeType: 'application/pdf')],
  fileNameOverrides: ['curriculum_vitae.pdf'],
));

// Desktop (Windows/macOS/Linux):
final path = await FilePicker.platform.saveFile(
  fileName: 'curriculum_vitae.pdf',
  type: FileType.custom,
  allowedExtensions: ['pdf'],
);
if (path != null) {
  await File(path).writeAsBytes(pdfBytes);
}
```

### Raccomandazione

**Scelta: `share_plus` v13.3.0 per mobile + `file_picker.saveFile()` per desktop + fallback download automatico di `share_plus` per Web.** Non servono dipendenze aggiuntive (`universal_html`, `download`, ecc.): i due pacchetti già scelti nelle aree 3 e 4 coprono tutti i target. L'unica lacuna è Linux via `share_plus` per la condivisione, ma il `saveFile()` di `file_picker` la compensa perfettamente aprendo il dialog nativo di sistema.

---

## 5. Storage Web (IndexedDB)

> Modello già deciso: un singolo object store `variants`, key = UUID (stringa), value = JSON blob completo (con asset base64 embedded).

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme | Stato manutenzione | Note |
|---|---|---|---|---|---|---|
| [`idb_shim`](https://pub.dev/packages/idb_shim) | tekartik / Alexandre Roux | `2.9.7+1` — 2026-08-18 | BSD-3-Clause | Web (IndexedDB nativo via `dart:js_interop`, WASM-compatible); VM/IO via `sembast` (per testing e desktop, non produzione web) | Molto attiva | API 1:1 con IndexedDB spec. Thin wrapper su Web. Dipende da `sembast` solo per l'implementazione IO/testing. Compatibile WASM. |
| [`sembast_web`](https://pub.dev/packages/sembast_web) | tekartik / Alexandre Roux | `2.4.5+1` — 2026-06-26 | BSD-3-Clause | Solo Web (usa IndexedDB tramite `idb_shim` internamente) | Attiva | NoSQL file-like store sopra IndexedDB. API sembast (store, finder, codec). Più astrazione di `idb_shim`. Utile se si usa già `sembast` su mobile/desktop per unificare l'API storage. |
| `indexed_db` / `web` package (Dart SDK) | Dart team | integrato in SDK Dart | BSD-3-Clause | Solo Web | Attiva (parte dell'SDK) | API raw IndexedDB tramite `dart:js_interop`. Massimo controllo ma richiede più boilerplate. Nessun shim per test/desktop. |

### Valutazione rispetto al modello richiesto

Per "un object store `variants`, key UUID, value JSON blob", `idb_shim` richiede il minimo codice:

```dart
import 'package:idb_shim/idb_browser.dart';

// Setup (una volta all'avvio)
final factory = getIdbFactory();
final db = await factory.open('cv_app', version: 1,
  onUpgradeNeeded: (VersionChangeEvent e) {
    e.database.createObjectStore('variants'); // key esplicita = UUID
  });

// Write (upsert)
final txn = db.transaction('variants', idbModeReadWrite);
await txn.objectStore('variants').put(variantJsonMap, uuidKey);
await txn.completed;

// Read one
final txn2 = db.transaction('variants', idbModeReadOnly);
final data = await txn2.objectStore('variants').getObject(uuidKey);
await txn2.completed;

// Read all
final txn3 = db.transaction('variants', idbModeReadOnly);
final all = await txn3.objectStore('variants').getAll();
await txn3.completed;

// Delete
final txn4 = db.transaction('variants', idbModeReadWrite);
await txn4.objectStore('variants').delete(uuidKey);
await txn4.completed;
```

### Raccomandazione

**Scelta: `idb_shim` v2.9.7+1.** Per il modello specificato (un solo store, key UUID, value JSON), è l'astrazione più diretta: thin wrapper sopra IndexedDB nativo sul Web, compatibile WASM (usa `dart:js_interop`), aggiornato attivamente, BSD-3-Clause, e permette di usare la stessa API anche in test su VM (via implementazione `sembast` in-memory).

**Piano B**: `sembast_web` se si vuole un'API NoSQL più high-level (codec, finder, versioning automatico) e si è disposti a portare la stessa API anche su mobile/desktop con `sembast` + `idb_sqflite`. Per un solo object store con accesso diretto per UUID, `idb_shim` è sufficiente e più leggero.

> **Nota**: questa libreria serve **solo per il layer Web**. Su mobile/desktop la persistenza avviene tramite `dart:io` (file JSON) o SQLite — fuori scope di questo report.

---

## 6. Serializzazione JSON

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Tipologia | Note |
|---|---|---|---|---|---|
| [`freezed`](https://pub.dev/packages/freezed) | Remi Rousselet (rrousselGit) | `4.0.0` — 2026-08-22 | MIT | Dev dependency (code-gen) | Code-gen per classi immutabili: `copyWith`, `==`, `hashCode`, union types, `toJson`/`fromJson` (via `json_serializable`). Flutter Favorite. Richiede Dart ≥3.13 dalla v4. |
| [`freezed_annotation`](https://pub.dev/packages/freezed_annotation) | Remi Rousselet | `3.1.0` — 2025-07-02 | MIT | Runtime dependency | Annotation companion di `freezed`. Va in `dependencies` (non `dev_dependencies`). |
| [`json_serializable`](https://pub.dev/packages/json_serializable) | Google / Dart team | `6.14.1` — 2026-07-30 | BSD-3-Clause | Dev dependency (code-gen) | Genera `toJson`/`fromJson`. Usato standalone o come backend di `freezed`. Supporta `@JsonKey(name: ...)`, default values, schema evolutivo. |
| [`json_annotation`](https://pub.dev/packages/json_annotation) | Google / Dart team | parte di `json_serializable` repo | BSD-3-Clause | Runtime dependency | Annotation companion di `json_serializable`. Va in `dependencies`. |
| [`dart_mappable`](https://pub.dev/packages/dart_mappable) | Kilian Schulte (schultek) | `4.8.0` — 2026-04-20 | MIT | Dev + Runtime | Alternativa moderna a `freezed`+`json_serializable`: generics nativi, no file `part`, ereditarietà, discriminated unions. Meno adottato nell'ecosistema Bloc ma tecnicamente più avanzato per casi complessi. |
| Serializzazione manuale | — | — | — | — | Nessun code-gen. Gestione manuale di `fromJson`/`toJson`. Non scalabile con >10 modelli e schema evolutivo. Non raccomandato. |

### Considerazioni per schema evolutivo con `schemaVersion`

Il ticket 03 prevede un campo `schemaVersion` nel JSON. Con `freezed` + `json_serializable`:

```dart
@freezed
class CvVariant with _$CvVariant {
  const factory CvVariant({
    required String id,
    @Default(1) int schemaVersion,
    required String title,
    required String summary,
    required List<Experience> experiences,
    // ...
  }) = _CvVariant;

  factory CvVariant.fromJson(Map<String, dynamic> json) =>
      _$CvVariantFromJson(json);
}
```

La migrazione da versione precedente può essere gestita in un `MigrationService` che legge `schemaVersion` *prima* della deserializzazione standard e trasforma il `Map<String, dynamic>` raw prima di chiamare `fromJson`.

### Raccomandazione

**Scelta: `freezed` v4.0.0 + `json_serializable` v6.14.1 + `freezed_annotation` v3.1.0 + `json_annotation` (companion).** Trio standard dell'ecosistema Bloc, immutabilità garantita, `copyWith` per state update in Bloc, schema evolutivo gestibile via `@Default` e migration layer. La v4.0.0 di `freezed` (rilasciata il 2026-08-22, il giorno prima di questa ricerca) introduce il supporto ai Dart 3.13 primary constructors ma mantiene retrocompatibilità con la sintassi classica.

**Piano B**: `dart_mappable` v4.8.0 se si vuole evitare il pattern `part` e si preferisce un approccio con `MapMapper`. Meno esempi nell'ecosistema Bloc ma superiore per generics e inheritance complessa.

---

## 7. Markdown Editor Flutter

> Il CV usa Markdown per tutti i campi di testo lungo (Sommario, descrizioni Esperienze/Formazione, ecc.).
> Requisiti: editor (input WYSIWYG o toolbar + sorgente Markdown) + preview, cross-platform totale (mobile + desktop + web).

### ⚠️ Avviso critico: `flutter_markdown` è DISCONTINUED

`flutter_markdown` v0.7.7+1 (ultima release 2025-05-06) è stato **marcato esplicitamente come discontinued** su pub.dev. Il campo `"isDiscontinued": true` è presente nella risposta API. Il suo successore ufficiale è **`flutter_markdown_plus`**. Non usare `flutter_markdown` in nuovi progetti.

### Tabella comparativa

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme (mobile/desktop/web) | Stato manutenzione | Funzionalità editor | Note |
|---|---|---|---|---|---|---|---|
| [`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus) | foresightmobile (fork ufficiale erede del Flutter team) | `1.0.12` — 2026-07-10 | MIT | ✅ Android, iOS, Windows, macOS, Linux, Web — Dart puro | Attiva | Solo **rendering/preview** — nessun componente di editing | Widget `Markdown(data: mdString)` e `MarkdownBody`. Tabelle GFM, task list, code blocks. Sostituto diretto di `flutter_markdown`. |
| [`flutter_markdown`](https://pub.dev/packages/flutter_markdown) | Flutter team | `0.7.7+1` — 2025-05-06 | MIT | ✅ tutte | **DISCONTINUED** — non usare | Solo rendering | Rimpiazzato da `flutter_markdown_plus`. Citato solo per completezza storica. |
| [`markdown_widget`](https://pub.dev/packages/markdown_widget) | asjqkkkk | `2.3.2+8` — 2025-04-26 | MIT | ✅ Dart puro, tutti i target | Moderata | Solo **rendering** con TOC, syntax highlighting codice | Non è un editor. Buono per preview più ricca (TOC, highlight). |
| [`markdown_editor_plus`](https://pub.dev/packages/markdown_editor_plus) | OmkarDabade | `0.2.15` — 2024-06-19 | MIT | Pubspec non specifica piattaforme; dipendenze Dart puro — ✅ probabilmente tutti i target | Bassa (ultima release >1 anno prima della ricerca) | **Editor sorgente** + toolbar Markdown + preview split | TextField con toolbar per bold/italic/lista/codice. Leggero. ⚠️ Dipende da `flutter_markdown` discontinued — rischio incompatibilità futura senza fork/aggiornamento. |
| [`appflowy_editor`](https://pub.dev/packages/appflowy_editor) | AppFlowy-IO | `6.2.0` — 2025-12-08 | **AGPL-3.0** ⚠️ | ✅ Android, iOS, Linux, macOS, Windows, Web (dichiarato nel pubspec `platforms`) | Molto attiva (backed by AppFlowy + 1000+ contributors) | **WYSIWYG block-based**: blocchi, toolbar floating, slash commands, import/export Markdown e Quill Delta built-in | Licenza AGPL-3.0: l'app che include questo pacchetto e viene distribuita **deve rendere disponibile il codice sorgente** se non è già open-source. |
| [`super_editor`](https://pub.dev/packages/super_editor) | Flutter Bounty Hunters / Superlist | `0.2.7` su pub.dev — 2024-06-11; sviluppo attivo su GitHub con developer releases | MIT | ✅ tutti i target dichiarati; nota: "unverified" su alcune piattaforme nel README | Attiva su GitHub; release rade su pub.dev | **Editor documenti ricco**: pipeline configurabile, undo/redo, selezione testo, formattazione, companion `super_editor_markdown` | Il team consiglia di dipendere direttamente dal repository GitHub per le versioni più recenti. Versione pub.dev conservativa (>1 anno). |

### Strategia raccomandata per il CV app

Per il caso d'uso (campi testuali brevi/medi in Markdown per Sommario e Descrizioni), sono praticabili due approcci:

**Approccio A — Leggero (raccomandato per MVP)**:
- **Editing**: `TextField` o `TextFormField` standard di Flutter + toolbar personalizzata con 5–6 azioni (grassetto, corsivo, lista, link, anteprima toggle).
- **Preview**: `flutter_markdown_plus` widget in un `Stack` o `TabBar` affiancato.
- Nessuna dipendenza aggiuntiva pesante; Markdown è testo semplice, il CV non necessita di un editor WYSIWYG block-based.
- Controllo totale sul layout e sulle animazioni della toolbar.

**Approccio B — Editor dedicato**:
- `appflowy_editor` v6.2.0 se **AGPL-3.0 è accettabile** (app open-source); export Markdown built-in, editor maturo e ricco.
- `super_editor` via dipendenza GitHub (MIT) se si vuole editor ricco senza vincoli AGPL e si accetta instabilità delle API.

### Raccomandazione

**Scelta per MVP: `flutter_markdown_plus` v1.0.12 (preview) + `TextField` nativo con toolbar custom minimale (editing).** Per il caso d'uso CV, questo approccio è sufficiente, evita dipendenze pesanti, e si integra naturalmente con il modello dati Bloc/Freezed. **Non usare `flutter_markdown` (discontinued).**

**Piano B editor ricco**: `appflowy_editor` v6.2.0 — ma **verificare la compatibilità AGPL-3.0 con i piani di distribuzione dell'app prima di adottarlo**. Se l'app è o diventa open-source, è il migliore disponibile. `super_editor` (MIT) via GitHub come terza opzione se si vuole editor ricco senza AGPL.

> ⚠️ **Trade-off licenza `appflowy_editor`**: AGPL-3.0 impone che qualsiasi software che *include* il pacchetto e viene distribuito (anche via web in SaaS) debba rendere disponibile il codice sorgente. Se l'app CV è o resterà closed-source, `appflowy_editor` **non è eleggibile**. In quel caso il piano B diventa `super_editor` (MIT) o l'Approccio A leggero.

---

## 8. `flutter_bloc` — State Management (già scelto)

| Libreria | Autore/maintainer | Ultima release + data | Licenza | Piattaforme | Stato manutenzione |
|---|---|---|---|---|---|
| [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) | Felix Angelov (felangel) | `9.1.1` — 2025-05-02 | MIT | ✅ Android, iOS, Windows, macOS, Linux, Web — Dart puro, zero dipendenze native | Molto attiva |

`flutter_bloc` v9.1.1 è Dart puro (dipende solo da `bloc` e `provider`) e funziona identicamente su tutte le piattaforme Flutter senza configurazioni aggiuntive. La licenza MIT, il sito di documentazione dedicato (bloclibrary.dev), il ricco ecosistema di pacchetti companion (`bloc_test` per testing, `hydrated_bloc` per persistenza automatica degli stati, `replay_bloc` per undo/redo) e la compatibilità nativa con modelli immutabili generati da `freezed` lo rendono la scelta standard per architetture Flutter scalabili. Nessuna alternativa valutata in questa sezione per decisione progettuale già presa.

---

## Stack Raccomandato per MVP

Lista compatta pronta da incollare nella spec tecnica. Una riga per area.

```
# Runtime dependencies
go_router @ ^17.5.0           — routing URL-based, deep linking, ShellRoute, Flutter team, BSD-3-Clause
pdf @ ^3.13.0                 — generazione PDF con widget-system Dart, Dart puro cross-platform, Apache-2.0
printing @ ^5.15.0            — consegna PDF (share/save/print) su tutte le piattaforme, Apache-2.0
file_picker @ ^12.0.0         — selezione file (import) + saveFile() su 6 piattaforme incl. Web/WASM, MIT
share_plus @ ^13.3.0          — share sheet mobile + download fallback Web + share desktop, BSD-3-Clause
idb_shim @ ^2.9.7+1           — IndexedDB Web: object store "variants", key UUID, value JSON, BSD-3-Clause
freezed_annotation @ ^3.1.0   — annotation runtime companion di freezed, MIT
json_annotation @ ^4.12.0     — annotation runtime companion di json_serializable, BSD-3-Clause
flutter_markdown_plus @ ^1.0.12 — rendering Markdown (preview CV), sostituto ufficiale di flutter_markdown, MIT
flutter_bloc @ ^9.1.1         — state management BLoC (già scelto), Dart puro cross-platform, MIT

# Dev dependencies (code generation)
build_runner                  — runner per tutti i code-gen (freezed, json_serializable)
freezed @ ^4.0.0              — generatore classi immutabili + union types, MIT
json_serializable @ ^6.14.1   — generatore toJson/fromJson, BSD-3-Clause
```

**Note sulle esclusioni dalla stack finale**:
- `file_selector` (Flutter team): non incluso perché `file_picker` è un superset funzionale per questo progetto (include `saveFile()` anche su mobile/web).
- `beamer`, `auto_route`: non inclusi — `go_router` è sufficiente per ~10 route.
- `sembast_web`: non incluso — `idb_shim` è più leggero per il modello a singolo store.
- `dart_mappable`: non incluso — `freezed` + `json_serializable` sono lo standard dell'ecosistema Bloc.
- **Editor Markdown**: non inserito nella stack MVP in attesa di decisione licenza AGPL (`appflowy_editor`). Se si sceglie l'Approccio A (leggero), non serve alcuna dipendenza aggiuntiva. Se si sceglie l'Approccio B, aggiungere:
  - `appflowy_editor @ ^6.2.0` (AGPL-3.0, solo se app open-source) **oppure**
  - dipendenza GitHub su `super_editor` (MIT, API beta)

---

## Riferimenti

### pub.dev
- `go_router`: <https://pub.dev/packages/go_router>
- `auto_route`: <https://pub.dev/packages/auto_route>
- `beamer`: <https://pub.dev/packages/beamer>
- `pdf`: <https://pub.dev/packages/pdf>
- `printing`: <https://pub.dev/packages/printing>
- `file_picker`: <https://pub.dev/packages/file_picker>
- `file_selector`: <https://pub.dev/packages/file_selector>
- `share_plus`: <https://pub.dev/packages/share_plus>
- `idb_shim`: <https://pub.dev/packages/idb_shim>
- `sembast_web`: <https://pub.dev/packages/sembast_web>
- `freezed`: <https://pub.dev/packages/freezed>
- `freezed_annotation`: <https://pub.dev/packages/freezed_annotation>
- `json_serializable`: <https://pub.dev/packages/json_serializable>
- `json_annotation`: <https://pub.dev/packages/json_annotation>
- `dart_mappable`: <https://pub.dev/packages/dart_mappable>
- `flutter_markdown_plus`: <https://pub.dev/packages/flutter_markdown_plus>
- `flutter_markdown` *(discontinued)*: <https://pub.dev/packages/flutter_markdown>
- `markdown_widget`: <https://pub.dev/packages/markdown_widget>
- `markdown_editor_plus`: <https://pub.dev/packages/markdown_editor_plus>
- `appflowy_editor`: <https://pub.dev/packages/appflowy_editor>
- `super_editor`: <https://pub.dev/packages/super_editor>
- `flutter_bloc`: <https://pub.dev/packages/flutter_bloc>

### Repository / Homepage
- `go_router` (GitHub): <https://github.com/flutter/packages/tree/main/packages/go_router>
- `pdf` + `printing` (GitHub): <https://github.com/DavBfr/dart_pdf>
- `file_picker` (GitHub): <https://github.com/miguelpruivo/flutter_file_picker>
- `file_selector` (GitHub): <https://github.com/flutter/packages/tree/main/packages/file_selector/file_selector>
- `share_plus` (GitHub): <https://github.com/fluttercommunity/plus_plugins/tree/main/packages/share_plus/share_plus>
- `idb_shim` (GitHub): <https://github.com/tekartik/idb_shim.dart/tree/master/idb_shim>
- `freezed` (GitHub): <https://github.com/rrousselGit/freezed>
- `dart_mappable` (GitHub): <https://github.com/schultek/dart_mappable>
- `flutter_markdown_plus` (GitHub): <https://github.com/foresightmobile/flutter_markdown_plus>
- `appflowy_editor` (GitHub): <https://github.com/AppFlowy-IO/appflowy-editor>
- `super_editor` (GitHub): <https://github.com/superlistapp/super_editor>
- `flutter_bloc` (homepage + docs): <https://bloclibrary.dev>

---

*Report generato il 2026-08-23. Versioni e date verificate tramite `pub.dev/api/packages/<nome>` alla stessa data.*