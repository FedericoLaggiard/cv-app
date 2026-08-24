# Gestione foto profilo e asset

Type: grilling
Status: closed
Blocked by: 03, 04

## Question

Come si gestiscono **foto profilo e altri asset binari** legati a una variante di CV, in modo che siano portabili tra piattaforme e sopravvivano all'export/import.

Punti da chiudere:
- La foto profilo è opzionale? Un solo asset o più (es. logo cliente, firma)?
- Storage: embed (base64) nel file JSON, o file separati referenziati da path relativi?
- Su web (IndexedDB) come si materializzano?
- Come vengono incluse nell'export PDF (dimensione, ridimensionamento, qualità)?
- Portabilità di un CV con foto: un utente esporta il JSON e lo re-importa su un'altra macchina — la foto viaggia con lui?
- Formati accettati (jpg, png, webp?) e limiti di dimensione.

Output atteso: decisione sul modello di storage degli asset + regole di export.

## Risoluzione

### Perimetro asset nell'MVP

**Un solo tipo di asset supportato**: la **foto profilo** referenziata da `Anagrafica.fotoProfiloAssetId`, opzionale.

Nessun altro asset è caricabile dall'utente:
- Non è possibile embeddare immagini dentro sezioni Markdown (custom o Sommario) — la sintassi `![](assetId)` non è supportata dai template MVP.
- Nessuna libreria media della variante.
- Nessun logo/badge/firma/screenshot portfolio.

Il modello del ticket 03 (`assets` store indirizzato per `assetId`, plurale per costruzione) resta invariato — supporta N asset a livello di formato file — ma nell'MVP l'UI ne referenzia uno solo. Espandere a più asset in v2 è additivo, non richiede migrazione dello schema.

### Pipeline di ingest

**Formati accettati in input**: `.jpg`, `.jpeg`, `.png`, `.webp`.

Formati esplicitamente **rifiutati**:
- **HEIC/HEIF** (default iOS): decoder cross-platform non-Dart-puro (problematico su Web/Linux). Messaggio: "Formato non supportato. Converti in JPG."
- **GIF**, **SVG**, **BMP**, **TIFF**: nessun caso d'uso per foto profilo.

**Aspect ratio**: nessun crop obbligatorio all'upload. Il template PDF decide come clippare (quadrato, cerchio, freeform). Semplifica UX MVP — niente cropper widget interattivo.

### Normalizzazione interna

Alla ricezione, l'immagine viene:

1. **Ridimensionata** con mantenimento aspect ratio: massimo **800 × 800 px** sul lato lungo. Se già più piccola, non viene upscalata.
2. **Riencodata a JPEG con qualità Q=85**. Alpha eventuale del PNG viene scartato (foto profilo non usa trasparenza).
3. **Verificata contro il limite hard**: massimo **500 KB** post-normalizzazione (pre-base64). Se supera, retry con qualità decrescente (Q=75 → Q=65). Se anche a Q=65 supera 500 KB, upload fallisce con messaggio "Foto troppo dettagliata, riduci risoluzione manualmente".

Motivi della normalizzazione:
- 800 px sul lato lungo copre agevolmente 30-40 mm di stampa @ 600 DPI: qualità di stampa piena senza gonfiare il `.cvapp`.
- JPEG Q=85 = compromesso standard qualità/dimensione (~50-200 KB tipici per un ritratto).
- Un solo formato interno = un solo path di decoding nei template.

### Storage

L'asset normalizzato viene encodato in base64 e scritto nell'`assets` store del JSON con la forma coerente col ticket 03:

```json
"assets": {
  "<assetId-uuid>": {
    "mimeType": "image/jpeg",
    "data": "<base64>"
  }
}
```

`Anagrafica.fotoProfiloAssetId` referenzia l'`assetId`. Alla rimozione della foto dall'editor, il riferimento in Anagrafica viene azzerato → al prossimo save il GC del ticket 03 rimuove l'entry dall'`assets` store.

### Contratto verso i template PDF (ticket 08)

- I template ricevono l'asset come `Uint8List` (JPEG decodificato dal base64). Consumato da `pw.MemoryImage(bytes)` senza re-encoding.
- Foto **assente**: il template deve renderizzare senza foto — layout adattato o zona foto rimossa. Non è un errore, è un caso standard.
- Foto **presente**: dimensione fisica (mm) e forma del clip (quadrato/cerchio/nessuno) = decisione del singolo template, non del layer asset.

### Portabilità

Coperta dal ticket 03: il `.cvapp` è autocontenuto (assets in base64), quindi export/import cross-device include automaticamente la foto senza gestione separata.

### Impatti su altri ticket

- **Ticket 07 (UX editor)**: UI di Anagrafica include uno slot "Foto profilo" con azioni **carica** (file picker con filtro `.jpg/.jpeg/.png/.webp`) e **rimuovi**. Nessun cropper interattivo. Feedback visibile per la normalizzazione (loading breve) e per errori (formato/limite dimensione).
- **Ticket 08 (design template PDF)**: ogni template deve specificare come renderizza la foto **quando presente** (dimensione, posizione, forma del clip) e **quando assente** (layout adattato). L'MVP non tenta di "rifloware intelligentemente" per accomodare/rimuovere la foto — ogni template ha due varianti di layout predefinite (con foto / senza foto) o un layout unico che regge entrambi i casi.
- **Ticket 13 (euristiche mapping PDF)**: già coerente. L'import PDF non estrae foto embedded. Dopo l'import l'utente carica la foto manualmente nell'editor.
