# Strategia OCR per PDF scansionati nell'MVP

Type: grilling
Status: closed
Blocked by: —  <!-- 10 chiuso -->

## Question

Come gestisce l'MVP i **PDF scansionati** (nessun text layer, solo immagini di pagina)?

Dalla [ricerca 05](05-ricerca-import-pdf.md):
- `flutter_tesseract_ocr` copre Android/iOS/Web ma su **desktop richiede packaging Tesseract nativo** custom.
- ML Kit on-device non gira su Web né desktop.
- Cloud OCR è escluso (no backend).

Punti da chiudere:
- OCR nell'MVP: **sì o no**? Se no, degradiamo esplicitamente a "questo PDF non è importabile, riempi a mano"?
- Se sì, su quali piattaforme? Solo mobile + web (dove `flutter_tesseract_ocr` funziona out-of-the-box)? Desktop deferred a v2?
- Come si rileva che un PDF è "scansionato" (assenza di text layer, o testo estratto quasi vuoto)?
- Trade-off UX: OCR è lento (secondi per pagina); serve progress + cancel?
- Language pack: quali lingue Tesseract distribuiamo? dimensione asset accettabile?

Output atteso: decisione binaria OCR nell'MVP, e se sì il perimetro (piattaforme + lingue + UX degradata).

## Input

- [Report di ricerca](assets/05-ricerca-import-pdf-report.md)
- [Ticket 10 (libreria PDF)](10-scelta-libreria-pdf.md) — la libreria scelta è anche il render engine sotto OCR.

## Risoluzione

### OCR: fuori scope MVP → v2

I PDF scansionati sono un caso **statisticamente marginale** per la nostra utenza: i CV nascono digitali (LinkedIn, Word, Google Docs, Canva, Overleaf) e conservano il text layer. Il caso "PDF stampato e scansionato" o "foto del cartaceo" è raro.

Implementare OCR nell'MVP costerebbe:
- `flutter_tesseract_ocr` copre Android/iOS/Web ma **non desktop** out-of-the-box → packaging Tesseract nativo custom per Windows/macOS/Linux, che rompe il vincolo "unica codebase";
- language pack Tesseract (ita+eng traineddata ~30–50 MB) gonfia il bundle sproporzionatamente per una feature usata da una minoranza;
- UX nuova richiesta (progress + cancel per operazione lenta);
- qualità OCR su CV con layout creativi comunque incerta (peggio di un text layer nativo).

Costo/beneficio negativo: fuori MVP. Riemergerà in v2 se e quando emergono lamentele reali.

### Rilevamento "PDF scansionato"

Dopo `pdfrx.loadStructuredText()`, calcolare:

```
avgCharsPerPage = fullText.length / pageCount
isScanned      = avgCharsPerPage < 100
```

Soglia relativa (per-page), non assoluta:
- robusta alle **briciole di OCR residuo** o watermark testuali che ingannerebbero un check `isEmpty`;
- tollera **CV cortissimi** genuini (un CV di 1 pagina ha comunque centinaia di caratteri);
- se produce un raro falso positivo, l'utente non è bloccato — vede il messaggio ma può proseguire con "crea da zero".

### UX degradata

Alla rilevazione del PDF scansionato l'utente vede un **dialog con due azioni**:

- Testo: *"Il PDF sembra un'immagine scansionata o un documento senza testo digitale. L'import automatico funziona solo con PDF che contengono testo selezionabile. Puoi creare il CV da zero nell'editor e ricopiare i dati manualmente."*
- Azione primaria: **"Crea CV da zero"** → apre editor vuoto (nuova variante).
- Azione secondaria: **"Annulla"** → torna alla libreria (nel caso l'utente abbia caricato il PDF sbagliato).

**No** opzione "importa comunque quel poco che c'è": le briciole di testo residuo in un PDF scansionato (numeri di pagina, watermark, timestamp) sono rumore, non dati del CV. Importarle contraddirebbe la strategia "auto-import puro con euristiche conservative" decisa nel ticket 10.

### Impatti su altri ticket

- Nessun impatto sul ticket 13 (euristiche): il rilevamento scansionato è **upstream** delle euristiche, non le tocca.
- Ticket 06 (stack): rimosso implicitamente un requisito su libreria OCR — nessun pacchetto OCR da valutare.
