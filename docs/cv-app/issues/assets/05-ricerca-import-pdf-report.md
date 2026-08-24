# Ricerca — Import PDF in Flutter/Dart

## Executive summary

Per un’app Flutter/Dart cross-platform **senza backend**, l’import da PDF è fattibile solo con aspettative realistiche: i PDF “nativi” con text layer sono importabili con parsing euristico + revisione utente; i PDF scansionati richiedono OCR; i CV creativi/multi-colonna non consentono un auto-mapping affidabile al 100%.

La libreria più interessante per copertura piattaforme è **`pdfrx`**: MIT, attiva, supporta Android/iOS/Windows/macOS/Linux e dichiara **Web (WASM)**; offre testo per pagina, bounding box per carattere/frammento, ricerca e rendering. **`syncfusion_flutter_pdf`** è la più ricca lato estrazione testo/font/stile/bounds, ma ha licenza Syncfusion commerciale/community e la documentazione pubblica enfatizza mobile + web più che desktop. Le librerie `pdfx`, `native_pdf_renderer`, `native_pdf_view`, `flutter_pdfview`, `pdf_render` e `printing` sono soprattutto viewer/rasterizer/printing: utili per preview o OCR, non per estrazione semantica strutturata. OCR on-device è praticabile su mobile con **ML Kit** o Tesseract; su Web `flutter_tesseract_ocr` usa Tesseract.js, mentre desktop resta il buco più delicato senza integrare Tesseract nativo/CLI.

Date release verificate su `pub.dev/api/packages/...` il 2026-08-23.

## Librerie candidate (tabella comparativa)

| Nome | Autore / maintainer | Ultima release + data pub.dev | Licenza | Piattaforme supportate, Web/WASM | Stato manutenzione | Note |
|---|---:|---:|---|---|---|---|
| [`syncfusion_flutter_pdf`](https://pub.dev/packages/syncfusion_flutter_pdf) | Syncfusion | `34.2.4` — 2026-08-18 | Syncfusion commercial / Community License | Documentazione: Android, iOS, Web; essendo Dart non-UI/non-FFI è potenzialmente usabile anche desktop, ma il supporto desktop va validato contrattualmente/PoC. Web: sì; WASM: non dichiarato esplicitamente. | Molto attiva | Migliore API di estrazione: testo, linee, parole, glyph, bounds, fontName/fontSize/fontStyle. Trade-off licenza. |
| [`pdfrx`](https://pub.dev/packages/pdfrx) | Takashi Kawasaki / espresso3389 | `2.4.7` — 2026-07-09 | MIT | Android, iOS, Windows, macOS, Linux, **Web (WASM)** dichiarato. | Attiva | Migliore candidata MIT cross-platform: viewer, rendering, testo grezzo/strutturato, char bounding boxes, search. Basata su PDFium. |
| [`pdfrx_engine`](https://pub.dev/packages/pdfrx_engine) | espresso3389 | `0.4.6` — 2026-07-09 | MIT | Engine Dart per pdfrx; native via PDFium; usato anche per Web/WASM tramite pdfrx. | Attiva | API low-level/engine: `loadText`, `loadStructuredText`, rendering/manipolazione. |
| [`pdfium_dart`](https://pub.dev/packages/pdfium_dart) | espresso3389 | `0.2.5` — 2026-06-13 | MIT; PDFium ha licenza propria BSD-style | Windows, Linux, Android, macOS; iOS tramite `pdfium_flutter`; **no Web/WASM generico via dart:ffi**. | Attiva | Binding FFI basso livello a PDFium. Potente ma richiede gestione nativa. |
| [`pdfium_flutter`](https://pub.dev/packages/pdfium_flutter) | espresso3389 | `0.2.3` — 2026-07-09 | MIT | Flutter native Android/iOS/Windows/macOS/Linux; **no Web**. | Attiva | Packaging PDFium per Flutter native; non è un importer alto livello. |
| [`pdfx`](https://pub.dev/packages/pdfx) | ScerIO / Serge Shkurko | `2.11.0` — 2026-08-20 | MIT | Android, iOS, macOS, Windows, Web via PDF.js; Linux non dichiarato nel pubspec. Web: sì via JS/PDF.js; WASM app Flutter: non esplicitato. | Attiva | Ottima per rendering/viewer. Non nasce per estrarre testo strutturato. |
| [`pdf_text`](https://pub.dev/packages/pdf_text) | Alessio Luciani | `0.5.0` — 2021-03-14 | MIT | Android, iOS only; **no Web/desktop**. | Stale | Estrae solo stringhe da documento/pagina; non bounds/layout. |
| [`flutter_pdf_text`](https://pub.dev/packages/flutter_pdf_text) | FaFre fork di `pdf_text` | `0.9.0` — 2025-02-13 | MIT | Android, iOS only; **no Web/desktop**. | Moderata | Fork aggiornato di `pdf_text`, ancora solo mobile. |
| [`printing`](https://pub.dev/packages/printing) | David PHAM-VAN | `5.15.0` — 2026-06-16 | Apache-2.0 | Android, iOS, macOS, Windows, Linux, Web; Web usa PDF.js; desktop usa PDFium per raster/print. | Attiva | Non è extractor; utile per `Printing.raster()` PDF→immagini, preview, stampa/share. |
| [`native_pdf_renderer`](https://pub.dev/packages/native_pdf_renderer) | RBC/Serge Shkurko | `5.0.0+1` — 2022-02-10 | MIT | Android, iOS, macOS, Windows, Web via PDF.js; no Linux dichiarato. | Di fatto sostituita da `pdfx` | Solo rendering pagina→immagine; README consiglia migrazione a `pdfx`. SDK constraint vecchio `<3.0.0`. |
| [`native_pdf_view`](https://pub.dev/packages/native_pdf_view) | RBC/Serge Shkurko | `6.0.0+1` — 2022-02-10 | MIT | Android, iOS, macOS, Windows, Web via PDF.js; no Linux dichiarato. | Di fatto sostituita da `pdfx` | Viewer sopra renderer; README consiglia migrazione a `pdfx`. SDK constraint vecchio. |
| [`flutter_pdfview`](https://pub.dev/packages/flutter_pdfview) | endigo | `1.4.5` — 2026-08-03 | MIT | Android, iOS only; **no Web/desktop**. | Attiva ma scope limitato | Viewer nativo con PDFKit/AndroidPdfViewer; roadmap cita desktop/web/search come “future plans”, quindi non adatta a import cross-platform. |
| [`pdf_render`](https://pub.dev/packages/pdf_render) | espresso3389 | `1.4.12` — 2024-08-26 | MIT | Android, iOS, macOS, Web via PDF.js; no Windows/Linux nel plugin moderno. | Maintenance mode | README dice esplicitamente: sostituita da `pdfrx`, no nuove feature. |
| [`pdfium_bindings`](https://pub.dev/packages/pdfium_bindings) | Isaque Neves / insinfo | `3.2.0` — 2026-01-08 | MIT; PDFium ha licenza propria | Dart/Flutter via `dart:ffi`; richiede binary PDFium accanto all’app; **no Web/WASM** tramite FFI. | Attiva | Wrapper low/high-level PDFium: rendering, page extract/merge, API C. Utile se si vuole costruire un layer custom, non plug-and-play. |
| [`flutter_pdfium`](https://pub.dev/packages/flutter_pdfium) | buehler | `1.0.2` — 2024-06-25 | non verificata dal package in questa ricerca; repo indica binding FFI | Android, iOS, macOS, Windows; **no Linux/Web** nel pubspec. | Bassa/moderata | Binding FFI PDFium; più giovane/minimale di `pdfrx`/`pdfium_dart`. |
| [`flutter_tesseract_ocr`](https://pub.dev/packages/flutter_tesseract_ocr) | khjde1207 | `0.4.31` — 2026-06-01 | BSD-3-Clause per plugin; dipendenze Tesseract/Tesseract.js con licenze proprie | Android, iOS, Web. Web usa Tesseract.js; WASM indiretto via Tesseract.js worker; no desktop dichiarato. | Aggiornata, ma setup fragile | OCR su immagini, non su PDF direttamente. Richiede rasterizzazione pagine + tessdata. |
| [`tesseract_ocr`](https://pub.dev/packages/tesseract_ocr) | arrrrny fork | `0.5.0` — 2025-06-15 | BSD-3-Clause | Android, iOS; no Web/desktop | Moderata | Fork più moderno, include Apple Vision iOS; non risolve cross-platform completo. |
| [`google_mlkit_text_recognition`](https://pub.dev/packages/google_mlkit_text_recognition) | flutter-ml community | `0.17.1` — 2026-08-17 | MIT per plugin; Google ML Kit SDK terms per runtime | Android, iOS only; **no Web/desktop** dichiarato chiaramente. | Attiva | OCR mobile migliore/veloce di Tesseract in molti casi; API restituisce blocchi/linee/elementi con bounding box. |
| [`pdf`](https://pub.dev/packages/pdf) | David PHAM-VAN | `3.13.0` — 2026-06-16 | Apache-2.0 | Dart puro; Web/Flutter ok per generazione | Attiva | Generazione PDF, non import CV. Non sostituisce un extractor. |
| [`pdftron_flutter` / Apryse](https://pub.dev/packages/pdftron_flutter) | Apryse | `1.0.1-58` — 2026-08-14 | Commerciale/proprietaria SDK | Pubspec: Android/iOS only; no Web/desktop | Attiva | Potente SDK documentale, ma non allinea il vincolo cross-platform richiesto e introduce licenza enterprise. |

## Capacità di estrazione per libreria

Legenda: ✅ supportato direttamente; ⚠️ possibile ma parziale/manuale; ❌ non supportato / non documentato come API principale.

| Libreria | Testo grezzo per pagina | Bounding box | Layout multi-colonna | Tabelle | Font/stile | Immagini embedded | Rendering pagina |
|---|---:|---:|---:|---:|---:|---:|---:|
| `syncfusion_flutter_pdf` | ✅ `PdfTextExtractor.extractText(startPageIndex: ...)` | ✅ `extractTextLines`, `findText`, bounds; line/word/glyph | ⚠️ ricostruibile da bounds + `layoutText`, non semantico | ⚠️ solo euristico da coordinate; non table extractor | ✅ `fontName`, `fontSize`, `fontStyle` su line/word/glyph | ⚠️ libreria gestisce immagini in PDF, ma import immagini embedded non è il focus della doc trovata | ❌ non è viewer/rasterizer pagina |
| `pdfrx` / `pdfrx_engine` | ✅ `PdfPage.loadText()` | ✅ `loadStructuredText()` con `charRects`, fragments, range bounds | ⚠️ ha analisi reading-order/line segmentation; CV creativi restano euristici | ⚠️ possibile dedurre colonne/gap; non table extractor | ❌ non espone font/stile nell’API testuale principale | ⚠️ manipola/importa immagini in PDF; non API principale di estrazione immagini | ✅ viewer + render PDFium/Web WASM |
| `pdfx` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ `PdfPage.render()` |
| `pdf_text` | ✅ documento e pagina | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `flutter_pdf_text` | ✅ documento e pagina | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `printing` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ `Printing.raster()` se disponibile sulla piattaforma |
| `native_pdf_renderer` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ pagina→immagine |
| `native_pdf_view` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ viewer |
| `flutter_pdfview` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ viewer; screenshot della view |
| `pdf_render` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ pagina/sub-area→immagine |
| `pdfium_bindings` | ⚠️ via API PDFium raw `FPDFText_*` | ⚠️ via API PDFium raw | ⚠️ tutto da implementare | ⚠️ tutto da implementare | ⚠️ dipende dalle API PDFium usate | ⚠️ possibile low-level | ✅ wrapper high-level render/PNG/JPEG |
| `pdfium_dart` / `pdfium_flutter` | ⚠️ via FFI PDFium | ⚠️ via FFI PDFium | ⚠️ tutto custom | ⚠️ tutto custom | ⚠️ tutto custom | ⚠️ tutto custom | ✅ se integrato correttamente |
| `flutter_pdfium` | ⚠️ via FFI PDFium | ⚠️ via FFI PDFium | ⚠️ tutto custom | ⚠️ tutto custom | ⚠️ tutto custom | ⚠️ tutto custom | ✅ |
| `flutter_tesseract_ocr` | ✅ OCR text da immagini | ⚠️ Web può restituire hOCR se configurato; nativo non documentato come API box-first | ⚠️ OCR con PSM; fragile | ⚠️ scarso senza post-processing | ❌ | ❌ | ❌, richiede rasterizer esterno |
| `google_mlkit_text_recognition` | ✅ OCR text | ✅ blocchi/linee/elementi con bounding box | ⚠️ blocchi utili, ma non layout CV semantico | ⚠️ non table extractor | ❌ | ❌ | ❌, richiede rasterizer esterno |

Osservazione chiave: per import CV serve distinguere **estrazione PDF text-layer** da **OCR**. Nessuna libreria Flutter/Dart trovata fornisce un “CV parser” semantico completo lato client. Le API migliori danno testo + geometria; la mappatura in sezioni `esperienza`, `formazione`, `skill`, date, aziende e ruoli resta logica applicativa.

## OCR e casi scansionati

### Quando serve OCR

Serve OCR quando:

- il PDF è una scansione/foto;
- il PDF contiene pagine raster senza text layer;
- il testo estratto è vuoto o quasi vuoto;
- un template esporta testo come curve/immagini;
- CV creativi usano sfondi/icone/colonne che rompono l’ordine di lettura.

Pipeline senza backend:

1. import PDF come bytes;
2. prova estrazione testo con `pdfrx` o `syncfusion_flutter_pdf`;
3. se testo assente o sotto soglia, rasterizza pagina a 200–300 DPI;
4. OCR immagine;
5. mostra risultato all’utente con campi suggeriti e correzione manuale.

### `flutter_tesseract_ocr`

Pro:

- Android/iOS + Web;
- usa Tesseract4Android, SwiftyTesseract e su Web richiede Tesseract.js;
- supporta tessdata custom e più lingue;
- Web possibile senza backend.

Contro:

- richiede gestione asset `tessdata`, `tessdata_config.json`, dimensione app maggiore;
- Tesseract è generalmente più lento di ML Kit, anche secondo la README del package;
- non è PDF-aware: serve prima rasterizzare ogni pagina;
- desktop non dichiarato;
- accuratezza su CV con layout complesso dipende molto da DPI, contrasto, lingua, PSM e qualità scansione.

### ML Kit

`google_mlkit_text_recognition` è ottimo per OCR mobile: Android/iOS, text blocks/lines/elements con bounding box, più script linguistici. Però il README dichiara esplicitamente che ML Kit è costruito per mobile e **Web/desktop non sono supportati**. È quindi una scelta forte solo se accetti un comportamento differenziato: OCR mobile buono, Web con Tesseract.js o manuale, desktop manuale o integrazione Tesseract nativa custom.

### Alternative on-device

- **Tesseract nativo desktop**: possibile tecnicamente con FFI/process e binari per Windows/macOS/Linux, ma non emerge un plugin Flutter maturo e cross-platform completo. Aumenta complessità di packaging.
- **Apple Vision**: disponibile solo su iOS/macOS nativo; il package `tesseract_ocr` cita Apple Vision su iOS, ma non risolve Android/Web/Windows/Linux.
- **Server OCR**: eliminato dal vincolo “senza backend”.

## Vincolo piattaforma web

Il Web è il vincolo più selettivo.

- `dart:ffi` è pensato per interoperabilità C nativa; i wrapper PDFium FFI (`pdfium_bindings`, `pdfium_dart`, `pdfium_flutter`, `flutter_pdfium`) non sono una soluzione Web diretta.
- `pdfrx` è l’eccezione più interessante: dichiara esplicitamente **Web (WASM)** nel README e nella descrizione supporta Android/iOS/Windows/macOS/Linux/Web.
- `pdfx`, `native_pdf_renderer`, `native_pdf_view`, `pdf_render` usano **PDF.js** su Web. Sono utili per rendering/preview, ma non per estrazione strutturata del CV.
- `printing` su Web usa PDF.js per preview/rasterizzazione; `Printing.raster()` dichiara che la disponibilità va verificata runtime con `Printing.info`.
- `syncfusion_flutter_pdf` non usa FFI ed è documentata per mobile + web; per Flutter Web è una candidata credibile per estrazione testo. Per **Flutter Web Wasm**, non ho trovato una dichiarazione esplicita “WASM supported”: va provata.
- `flutter_tesseract_ocr` su Web usa Tesseract.js tramite script in `index.html`; è Web-compatibile, ma l’integrazione è JS/worker e non un parser PDF.

Conclusione Web: se il requisito è “una singola codebase senza backend e Web incluso”, evitare librerie solo FFI o solo mobile come componente centrale. Usare `pdfrx` o `syncfusion_flutter_pdf` per text layer, e prevedere fallback OCR/manuale.

## Cosa aspettarsi su CV reali

| Tipo CV | Aspettativa tecnica | Strategia consigliata |
|---|---|---|
| Export LinkedIn PDF | Di solito text layer leggibile, layout abbastanza regolare. Heading e date spesso estraibili. | Estrazione testo per pagina; regex/euristiche per email, telefono, link, sezioni; conferma utente. |
| Word / Google Docs → PDF | Buona qualità text layer; ordine di lettura generalmente lineare se template semplice. | `pdfrx.loadStructuredText()` o Syncfusion `extractTextLines`; mapping assistito con confidence score. |
| CV Europass / template tradizionale | Buona leggibilità, ma possono esserci colonne laterali per skill/contatti. | Usare bounding box per segmentare sidebar vs corpo principale; non solo testo concatenato. |
| Canva / template creativo multi-colonna | Spesso testo spezzato in frammenti, icone, layer decorativi, ordine non naturale; talvolta testo rasterizzato. | Import assistito: preview pagina + campi suggeriti; bounding box aiuta ma non garantisce semantica. |
| CV scansionato / foto in PDF | Nessun text layer; estrazione PDF produce vuoto o rumore. | Rasterizzazione + OCR; su mobile ML Kit/Tesseract, su Web Tesseract.js; su desktop fallback manuale o Tesseract nativo custom. |
| PDF protetto/password | Supporto variabile. `pdfrx` e `pdf_text` supportano password; Syncfusion apre PDF esistenti e gestisce sicurezza. | UI per password; se owner permissions vietano extraction, degradare a manuale/OCR solo se legalmente consentito. |

## Strategie di import: cosa è abilitato / eliminato

### Abilitate

1. **Import assistito text-layer first**
   - Import file con `file_picker`.
   - Lettura bytes.
   - Estrazione con `pdfrx` o `syncfusion_flutter_pdf`.
   - Normalizzazione testo per pagina.
   - Detection sezioni: profilo, esperienza, formazione, skill, lingue, contatti.
   - Confidence score per campo.
   - UI di revisione prima del salvataggio.

2. **Import layout-aware leggero**
   - Usare bounding box per distinguere colonne/sidebar.
   - Ordinare righe per `y`, poi clusterizzare per `x`.
   - Utile per CV a due colonne.
   - Non è table/semantic parsing vero.

3. **Fallback OCR per scansioni**
   - Rasterizzare pagina con `pdfrx`, `pdfx`, `printing` o PDFium.
   - OCR mobile con ML Kit o Tesseract.
   - OCR Web con `flutter_tesseract_ocr`/Tesseract.js.
   - Desktop: fallback manuale oppure integrazione Tesseract custom.

4. **Import manuale assistito**
   - Sempre necessario come fallback.
   - Mostrare PDF a sinistra, form a destra.
   - Precompilare solo campi ad alta confidenza.

### Eliminate / non realistiche

- **Auto-mapping completo e affidabile per tutti i CV PDF senza backend**: non realistico. Il PDF non conserva necessariamente struttura semantica; colonne, tabelle finte, icone, canvas e testo rasterizzato rompono l’ordine logico.
- **Un’unica libreria gratuita MIT che faccia text extraction, layout semantics, OCR e Web/desktop/mobile perfetti**: non trovata.
- **OCR uniforme mobile + desktop + web con plugin Flutter maturo unico**: non trovato. ML Kit è mobile-only; Tesseract Flutter è mobile/web ma non desktop.
- **Usare viewer-only come parser CV**: `flutter_pdfview`, `pdfx`, `pdf_render`, `native_pdf_view`, `native_pdf_renderer` non bastano per estrazione semantica; servono solo per preview/raster.

## Raccomandazione

### Opzione consigliata MIT-first

Usare **`pdfrx`** come libreria primaria.

Motivi:

- copertura dichiarata Android/iOS/Windows/macOS/Linux/Web;
- Web dichiarato come **WASM**;
- licenza MIT;
- rendering e viewer inclusi;
- API `loadText()` e `loadStructuredText()` con `fullText`, `charRects`, fragments, direction e search ranges;
- base PDFium moderna e attiva.

Trade-off:

- niente font/stile nell’API testuale principale;
- layout multi-colonna/tabelle restano euristiche;
- dipendenze PDFium/native assets aumentano dimensione e complessità;
- per OCR desktop resta necessario lavoro custom o fallback manuale.

### Opzione premium / extraction-rich

Valutare **`syncfusion_flutter_pdf`** come seconda libreria primaria se la licenza è accettabile.

Motivi:

- estrazione molto più ricca: linee/parole/glyph con `bounds`, `fontName`, `fontSize`, `fontStyle`;
- `findText()` restituisce match con bounds e pageIndex;
- non usa FFI, quindi è più amichevole per Web rispetto ai binding nativi.

Trade-off licenza:

- richiede licenza Syncfusion commerciale o Community License;
- Community License: limiti pubblici includono ricavi annui sotto 1M USD, 5 o meno sviluppatori, 10 o meno dipendenti e vincoli su capitale esterno;
- per prodotto commerciale non qualificato, va preventivato costo/licenza.

### Strategia prodotto raccomandata

Implementare **import assistito**, non auto-import totale:

1. text-layer extraction con `pdfrx` come default;
2. se serve font/stile o qualità extraction maggiore, PoC comparativo con `syncfusion_flutter_pdf`;
3. parser euristico locale con confidence score;
4. preview PDF + form di correzione;
5. OCR solo come fallback:
   - mobile: `google_mlkit_text_recognition` preferibile;
   - web: `flutter_tesseract_ocr`/Tesseract.js;
   - desktop: manuale o ticket dedicato per Tesseract nativo.

Decisione sintetica: **`pdfrx` + import assistito** è la scelta più coerente con cross-platform + no backend + licenza permissiva. **Syncfusion** è la scelta più forte se il valore del parsing layout/font giustifica il rischio/costo licenza e se il supporto desktop viene validato.

## Fonti

- `syncfusion_flutter_pdf` pub.dev API: https://pub.dev/api/packages/syncfusion_flutter_pdf
- `syncfusion_flutter_pdf` pub page: https://pub.dev/packages/syncfusion_flutter_pdf
- Syncfusion `PdfTextExtractor`: https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfTextExtractor-class.html
- Syncfusion `extractText`: https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfTextExtractor/extractText.html
- Syncfusion `extractTextLines`: https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfTextExtractor/extractTextLines.html
- Syncfusion `MatchedItem`: https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/MatchedItem-class.html
- Syncfusion Community License: https://www.syncfusion.com/products/communitylicense
- `pdfrx` pub.dev API: https://pub.dev/api/packages/pdfrx
- `pdfrx` package: https://pub.dev/packages/pdfrx
- `pdfrx` repo README: https://github.com/espresso3389/pdfrx
- `pdfrx_engine` pub.dev API: https://pub.dev/api/packages/pdfrx_engine
- `pdfrx_engine` `PdfPage.loadText`: https://pub.dev/documentation/pdfrx_engine/latest/pdfrx_engine/PdfPage/loadText.html
- `pdfrx_coregraphics` pub page: https://pub.dev/packages/pdfrx_coregraphics
- `pdfx` pub.dev API: https://pub.dev/api/packages/pdfx
- `pdfx` pub page / README: https://pub.dev/packages/pdfx
- `pdfx` `PdfPage.render`: https://pub.dev/documentation/pdfx/latest/pdfx/PdfPage/render.html
- `pdf_text` pub.dev API: https://pub.dev/api/packages/pdf_text
- `pdf_text` README: https://github.com/AlessioLuciani/flutter-pdf-text
- `flutter_pdf_text` pub.dev API: https://pub.dev/api/packages/flutter_pdf_text
- `flutter_pdf_text` README: https://github.com/FaFre/flutter-pdf-text
- `printing` pub.dev API: https://pub.dev/api/packages/printing
- `printing` pub page: https://pub.dev/packages/printing
- `printing` `Printing.raster`: https://pub.dev/documentation/printing/latest/printing/Printing/raster.html
- `native_pdf_renderer` pub.dev API: https://pub.dev/api/packages/native_pdf_renderer
- `native_pdf_renderer` pub page: https://pub.dev/packages/native_pdf_renderer
- `native_pdf_view` pub.dev API: https://pub.dev/api/packages/native_pdf_view
- `native_pdf_view` pub page: https://pub.dev/packages/native_pdf_view
- `flutter_pdfview` pub.dev API: https://pub.dev/api/packages/flutter_pdfview
- `flutter_pdfview` pub page: https://pub.dev/packages/flutter_pdfview
- `pdf_render` pub.dev API: https://pub.dev/api/packages/pdf_render
- `pdf_render` pub page: https://pub.dev/packages/pdf_render
- `pdfium_bindings` pub.dev API: https://pub.dev/api/packages/pdfium_bindings
- `pdfium_bindings` pub page: https://pub.dev/packages/pdfium_bindings
- `pdfium_dart` pub.dev API: https://pub.dev/api/packages/pdfium_dart
- `pdfium_dart` pub page: https://pub.dev/packages/pdfium_dart
- `pdfium_flutter` pub.dev API: https://pub.dev/api/packages/pdfium_flutter
- `flutter_pdfium` pub.dev API: https://pub.dev/api/packages/flutter_pdfium
- `flutter_tesseract_ocr` pub.dev API: https://pub.dev/api/packages/flutter_tesseract_ocr
- `flutter_tesseract_ocr` pub page: https://pub.dev/packages/flutter_tesseract_ocr
- `flutter_tesseract_ocr` repo: https://github.com/khjde1207/tesseract_ocr
- `tesseract_ocr` pub.dev API: https://pub.dev/api/packages/tesseract_ocr
- `tesseract_ocr` repo: https://github.com/arrrrny/tesseract_ocr
- `google_mlkit_text_recognition` pub.dev API: https://pub.dev/api/packages/google_mlkit_text_recognition
- `google_mlkit_text_recognition` pub page: https://pub.dev/packages/google_mlkit_text_recognition
- `google_mlkit_text_recognition` repo README: https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_text_recognition
- Dart `dart:ffi` API: https://api.dart.dev/stable/latest/dart-ffi/
- `pdf` pub.dev API: https://pub.dev/api/packages/pdf
- `pdftron_flutter` pub.dev API: https://pub.dev/api/packages/pdftron_flutter
