# Scelta della libreria PDF primaria per l'import

Type: grilling
Status: closed

## Question

Decidere tra le due candidate emerse dalla [ricerca 05](05-ricerca-import-pdf.md):

- **`pdfrx`** — MIT, tutte le piattaforme incluso Web WASM, API `loadStructuredText()` con `charRects` e fragments, base PDFium. Non espone font/stile.
- **`syncfusion_flutter_pdf`** — licenza community (vincoli su fatturato/uso commerciale), estrazione più ricca (linee/parole/glyph con `bounds`, `fontName`, `fontSize`, `fontStyle`), no-FFI.

Punti da chiudere:
- La licenza Syncfusion Community è compatibile con la roadmap dell'app (uso personale? distribuzione? monetizzazione futura?).
- Il set di segnali `pdfrx` (testo + bounding box, no stile) è sufficiente per euristiche di mapping ragionevoli, o servono davvero font/stile per riconoscere titoli di sezione?
- Costo di manutenzione: cambiare libreria in v2 è possibile? il repository `CvRepository` isola già i byte, ma l'API di parsing no.
- Fallback: se scegliamo `pdfrx` ma incontriamo un limite, valutare Syncfusion tardivamente è realistico?

Output atteso: decisione della libreria primaria per l'MVP + motivazione + eventuale "piano B" per casi in cui la prima fallisce.

## Input

- [Report di ricerca](assets/05-ricerca-import-pdf-report.md)

## Risoluzione

### Decisione a monte: strategia di import

Prima della scelta libreria è stata esplicitata la strategia di import per l'MVP, che finora era solo una raccomandazione dell'analista propagata implicitamente:

- **Auto-import puro**: l'utente sceglie il PDF → l'app estrae → apre l'editor **pre-riempito** con quello che è riuscita a mappare.
- **Nessuna UX di revisione dedicata**: l'editor normale del CV è la superficie di correzione.
- **Frammenti non mappati**: scartati. L'utente completa i campi mancanti a mano nell'editor.
- **Import assistito**: **fuori scope MVP → v2**.

Conseguenza sulla scelta libreria: la qualità dell'auto-mapping è direttamente la qualità percepita dell'import, quindi i segnali estratti dalla libreria contano.

### Libreria primaria: `pdfrx`

**Motivazione**: `pdfrx` è l'unica candidata su pub.dev che soddisfa **contemporaneamente** i tre vincoli fissi:

1. **Licenza permissiva** — MIT. Nessun vincolo su distribuzione, monetizzazione, dimensione del team, capitale esterno. L'utente ha esplicitamente escluso librerie con licenze non-open (Syncfusion Community, Apryse, ecc.), a prescindere dalla convenienza tecnica.
2. **Cross-platform reale incluso Web WASM** — Android, iOS, Windows, macOS, Linux, Web (via PDFium compilato WASM). Coerente col vincolo "unica codebase mobile+desktop+web".
3. **Estrazione strutturata** — `loadStructuredText()` restituisce `fullText`, `charRects` (bounding box per carattere), fragments. Sufficiente per euristiche geometriche.

Le alternative permissive più potenti (`pdfium_dart`, `pdfium_bindings`) sono FFI e **non girano su Web**: sceglierle imporrebbe una doppia implementazione desktop/web per zero guadagno tecnico rispetto a `pdfrx`, che sotto il cofano è comunque PDFium.

### Cosa perdiamo rispetto a Syncfusion

`pdfrx` **non espone font metadata** (fontName, fontSize, fontStyle). Impatto sulle euristiche di mapping (ticket 13):

| Segnale | Serve stile? | Perdiamo qualcosa con `pdfrx`? |
| --- | --- | --- |
| Regex email/telefono/URL → Contatti | No | No |
| Regex date "MM YYYY" / range → Esperienze/Formazione | No | No |
| Dizionario multilingua titoli sezione ("Experience", "Esperienze", "Erfahrung", …) | No | No |
| Titoli non-standard fuori dizionario ("Il mio percorso", "Cose che ho fatto") | Sì | Sì, ma **proxy geometrico** disponibile |

**Proxy geometrico**: l'altezza del bounding box carattere in `charRects` è direttamente proporzionale alla font size. Combinata con la spaziatura verticale sopra/sotto un blocco, permette di riconoscere "titolo vs corpo" senza font metadata espliciti. Dettaglio del come nel ticket 13.

I titoli di sezione con nomi molto creativi e stile tipografico non evidente non saranno riconosciuti — l'utente li ricostruisce a mano nell'editor, coerente con la strategia auto-import puro.

### Piano B

**Non è "cambia libreria"** (non ci sono alternative permissive equivalenti). È **graceful degradation** su casi noti:

| Caso | Rilevamento | Comportamento |
| --- | --- | --- |
| PDF password-protected | `pdfrx` alza errore specifico | UI chiede la password; se fallisce, messaggio "PDF protetto, riempi a mano" |
| PDF scansionato (no text layer) | `loadStructuredText()` restituisce testo vuoto o quasi | Messaggio "sembra un'immagine scansionata, l'import automatico non è disponibile"; OCR è ticket 12 |
| Layout caotico (Canva multi-colonna, reading order rotto) | Basso numero di campi mappati con successo | Editor si apre con i campi che siamo riusciti a riempire; il resto resta vuoto — comportamento standard dell'auto-import puro |
| Bug/crash `pdfrx` su Web WASM | PoC di implementazione lo rileverebbe | Piano B **feature**, non libreria: disabilitare import su Web con messaggio esplicito |

### Impatti su altri ticket

- **Ticket 11 (UX import assistito)** → chiuso come **fuori scope MVP** (v2).
- **Ticket 13 (euristiche mapping PDF)** → resta MVP; non è più bloccato da 11; perimetro modificato: euristiche **conservative** (mappa solo se sicuro), niente confidence score visibile all'utente, aggiunta esplicita dei proxy geometrici (altezza bbox, spaziatura verticale) come sostituti dei font metadata.
- **Ticket 12 (OCR scansionati)** → invariato, ancora bloccato da 10 (ora sbloccato).
- **Mappa `map.md`** → aggiunta della decisione "strategia di import auto-only" e della decisione "libreria PDF = pdfrx".
