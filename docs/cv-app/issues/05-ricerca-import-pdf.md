# Ricerca fattibilità import PDF

Type: research
Status: closed
Assignee: wayfinder-agent

## Question

Ricerca approfondita sulle **librerie Flutter/Dart per parsing PDF** e su cosa è realisticamente ottenibile per l'import di un CV esistente.

Punti da coprire nel report:
- Elenco delle librerie pub.dev candidate (es. `syncfusion_flutter_pdf`, `pdfx`, `pdf_text`, altre) con licenza, ultima release, piattaforme supportate (attenzione a web).
- Capacità di ciascuna: solo testo grezzo? posizioni? riconoscimento layout / colonne? tabelle? font? immagini?
- Alternative: rendering + OCR (es. Tesseract via FFI) — costo/beneficio per CV nativi vs scansionati.
- Esempi reali: cosa si ottiene provando su 2–3 CV tipici (LinkedIn export, Word→PDF, template designer).
- Vincoli per la strategia di import (auto vs assistito vs manuale) che la ricerca *elimina* o *abilita*.
- Raccomandazione: quali librerie tenere come candidate primarie.

Output atteso: file markdown di report linkato in questo ticket. Non prendere ancora la decisione sulla strategia — quella graduerà come ticket separato dopo la ricerca.

## Risoluzione

**Report**: [Ricerca — Import PDF in Flutter/Dart](assets/05-ricerca-import-pdf-report.md)

**Sintesi**:

- Le librerie realmente rilevanti per l'MVP sono due: **`pdfrx`** (MIT, attiva, copre Android/iOS/desktop/Web WASM, API `loadText()`/`loadStructuredText()` con `fullText` + `charRects` + fragments, base PDFium moderna) e **`syncfusion_flutter_pdf`** (estrazione più ricca — linee/parole/glyph con `bounds`, `fontName`, `fontSize`, `fontStyle`; no-FFI quindi web-friendly; licenza community con vincoli commerciali).
- **`pdf_text` è morta** (ultima release 2021, solo Android/iOS). `pdfx`, `native_pdf_renderer`, `native_pdf_view`, `flutter_pdfview`, `pdf_render`, `printing` sono **viewer/render**, non parser semantici: utili solo per anteprima o come step di rendering per OCR.
- I wrapper **PDFium via FFI** (`pdfium_bindings` e affini) sono potenti ma **non funzionano su Web** (dart:ffi assente), quindi non risolvono il vincolo cross-platform da soli.
- **Auto-mapping completo eliminato**: CV Canva/creativi multi-colonna hanno ordine di lettura instabile; anche con bounding box l'attribuzione a sezioni è euristica e fragile. **Import assistito** (estrai testo con bounding box → mostra all'utente affiancato al PDF → drag/drop/copy-paste verso i campi dello schema) è la strategia realistica e abilitata.
- **OCR per scansionati**: `flutter_tesseract_ocr` copre Android/iOS/Web ma su **desktop richiede packaging Tesseract nativo custom**. Per l'MVP è ragionevole rimandare OCR o degradare a "solo manuale" per scansionati.
- **Raccomandazione analista**: partire con **`pdfrx`** come candidato primario (MIT, tutte le piattaforme, rendering + estrazione strutturata), tenere **`syncfusion_flutter_pdf`** come alternativa premium se licenza accettata. Strategia MVP = import assistito, non auto-import.
