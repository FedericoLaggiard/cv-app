# Scelta dello stack Flutter (state mgmt, PDF export, file picker, routing)

Type: research
Status: closed

## Question

Selezionare le **librerie chiave** dello stack Flutter per l'MVP, con motivazione, per ognuna delle aree seguenti:

- **State management**: Riverpod, Bloc, Provider, signals, altro?
- **Routing**: go_router, auto_route, altro?
- **PDF export**: `pdf` + `printing` (di Nohus/DavBfr), Syncfusion, altro? Vincolo: deve funzionare su tutte e 3 le piattaforme.
- **File picker cross-platform** (import PDF, scegliere cartelle salvataggio): `file_picker`, `file_selector`, altro?
- **Salvataggio/condivisione file esportati**: `share_plus`, `printing`, download browser, ecc.
- **Storage web**: pacchetto per IndexedDB (`idb_shim`, `sembast_web`, altro).
- **Serializzazione JSON**: `json_serializable` + `freezed`? Manuale? Altro?

Per ogni scelta: giustificazione in 2–3 righe (piattaforme supportate, manutenzione attiva, licenza, complessità).

Output atteso: sezione "Stack" pronta da inserire nella spec MVP.

## Vincoli decisi a monte

- I campi lunghi (Sommario, descrizioni Esperienze/Formazione/Certificazioni, Note Lingue, campo Skill) usano **Markdown** (vedi [ticket 01](01-schema-dati-cv.md)). Aggiungere "editor Markdown Flutter" tra le aree da valutare.
- **State management già scelto**: `flutter_bloc` (Bloc + Cubit). Vedi mappa "Vincoli fissi" e [ticket 04](04-storage-per-piattaforma.md). Non riaprire la scelta; la ricerca copre solo giustificazione sintetica (piattaforme supportate, licenza, manutenzione attiva).
- **Storage web già disegnato** in [ticket 04](04-storage-per-piattaforma.md): un solo object store `variants` in IndexedDB, key = UUID, value = oggetto JSON completo. La ricerca su questa area valuta solo il pacchetto Dart più adatto a esporre questo modello (candidati principali: `idb_shim`, `sembast_web`).
- **Import/export bordo**: il repository parla `Uint8List`. Il file picker / save dialog / download browser / share sheet vivono sopra, e la ricerca deve confrontarli in ottica "input/output di byte", non "handle di file".

## Risoluzione

**Report**: [Ricerca — Stack Flutter per CV App MVP](assets/06-stack-flutter-report.md)

### Stack MVP (definitivo)

| Area | Scelta | Licenza | Motivo |
| --- | --- | --- | --- |
| **State management** | `flutter_bloc` ^9.1.1 | MIT | Già scelto (vincolo fisso). Dart puro, cross-platform totale, ecosistema maturo, integrazione nativa con `freezed`. |
| **Routing** | `go_router` ^17.5.0 | BSD-3-Clause | Mantenuto dal Flutter team, deep linking nativo, `ShellRoute` per layout con sidebar/bottom bar, zero code-gen. `auto_route`/`beamer` scartati (code-gen non necessario / manutenzione più lenta). |
| **PDF export** (generazione) | `pdf` ^3.13.0 + `printing` ^5.15.0 | Apache-2.0 | Unica combo permissiva cross-platform vera per generazione PDF da widget Dart. Stesso autore (David PHAM-VAN), release sincronizzate. Syncfusion escluso per policy licenza. |
| **File picker** (import) | `file_picker` ^12.0.0 | MIT | Superset funzionale di `file_selector`: copre tutte le 6 piattaforme incluso Web/WASM, restituisce `Uint8List` diretto, include già `saveFile()` (riutilizzato per l'export). |
| **Save/share export** | `share_plus` ^13.3.0 + `file_picker.saveFile()` | BSD-3-Clause / MIT | `share_plus` per share sheet mobile + download fallback Web; `file_picker.saveFile()` per dialog "salva con nome" su desktop e per la lacuna Linux (`share_plus` non condivide file su Linux). |
| **Storage Web (IndexedDB)** | `idb_shim` ^2.9.7+1 | BSD-3-Clause | Thin wrapper 1:1 su IndexedDB nativo via `dart:js_interop`, WASM-compatible. Perfetto per il modello del ticket 04 (single object store `variants`, key UUID, value JSON blob). `sembast_web` scartato — più astrazione del necessario. |
| **Serializzazione JSON** | `freezed` ^3.x pinned + `json_serializable` ^6.14.1 + companion annotations | MIT / BSD-3-Clause | Standard de-facto ecosistema Bloc. Classi immutabili con `copyWith`/`==`/`hashCode`, `toJson`/`fromJson`, `@Default` per schema evolutivo (ticket 03). **v3.x pinned e non v4.0.0** (rilasciato 2026-08-22, un giorno prima della ricerca): sulla release fresca il rischio bug di regressione è concreto e il vantaggio (primary constructors Dart 3.13) è cosmetico. Bump alla v4 rimandato a quando avrà 1-2 mesi di storia. `dart_mappable` scartato per omogeneità con l'ecosistema Bloc. |
| **Markdown rendering** (preview) | `flutter_markdown_plus` ^1.0.12 | MIT | ⚠️ `flutter_markdown` è **discontinued**, `flutter_markdown_plus` è il fork ufficiale erede. Widget `Markdown`/`MarkdownBody`, tabelle GFM, code blocks. |
| **Markdown editor** (input WYSIWYG) | `super_editor` (via GitHub) + `super_editor_markdown` | MIT | Editor documenti ricco WYSIWYG. Formato di storage resta Markdown puro (ticket 01/03); `super_editor_markdown` gestisce il round-trip WYSIWYG ↔ Markdown. Dipendenza da GitHub commit hash (release pub.dev vecchia); il team consiglia esplicitamente questa modalità. `appflowy_editor` scartato per **AGPL-3.0** (viola la policy "nessun vincolo sulla distribuzione", stessa logica dell'esclusione Syncfusion). Approccio A (leggero: `TextField` + toolbar custom + `flutter_markdown_plus` preview) resta come **fallback documentato** se `super_editor` risulta troppo instabile in fase di implementazione — reversibile perché lo storage è Markdown puro. |

**Dev dependencies aggiuntive**:
- `build_runner` — runner code-gen per `freezed` e `json_serializable`

### Esclusioni esplicite

- **`file_selector`** (Flutter team): superato da `file_picker` perché quest'ultimo include `saveFile()` anche su mobile/web (`file_selector.getSaveLocation()` è solo desktop).
- **`beamer`**, **`auto_route`**: `go_router` è sufficiente per il numero di route dell'app.
- **`sembast_web`**: `idb_shim` è più leggero per il modello a singolo store.
- **`dart_mappable`**: valido tecnicamente, ma frizionerebbe con esempi/documentazione Bloc-centrici.
- **`appflowy_editor`**: **escluso per licenza AGPL-3.0** (vincoli sulla distribuzione, contrasta la policy licenze).
- **`flutter_markdown`**: **discontinued** — sostituito da `flutter_markdown_plus`.
- **`syncfusion_flutter_pdf`**, **Apryse/PDFtron**: già esclusi in mappa (vincolo fisso licenze).

### Trade-off consapevolmente accettati

- **`super_editor` via GitHub**: API instabile e aggiornamenti senza release notes semver. Rischio mitigato incapsulando l'editor dietro un'interfaccia interna che sopporta lo swap all'Approccio A senza toccare lo storage (Markdown puro).
- **`freezed` v3.x pinned**: nessun accesso ai primary constructors Dart 3.13 finché non bumpiamo a v4 (previsto quando avrà maturato).
- **`share_plus` non condivide file su Linux**: coperto dal fallback `file_picker.saveFile()` — comportamento leggermente diverso su Linux (dialog "salva con nome" invece di share sheet), ma funzionale.

### Impatti su altri ticket

- **Ticket 07 (UX editor)**: l'editor Markdown WYSIWYG di `super_editor` cambia il feel dell'editor rispetto a "textarea + toolbar". Va tenuto presente nel design del layout dei campi lunghi (Sommario, descrizioni).
- **Ticket 08 (template PDF)**: i template saranno hard-coded come composizioni di widget `pw.*` del package `pdf`. Le famiglie di font vanno caricate da asset Flutter con `fontFromAssetBundle`.
- **Ticket 09 (foto e asset)**: la gestione asset base64 embedded si serializza automaticamente col resto del JSON via `freezed` + `json_serializable`.
