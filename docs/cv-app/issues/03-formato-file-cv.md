# Formato di serializzazione dei file CV

Type: grilling
Status: closed
Blocked by: 01

## Question

Definire il **formato del file** in cui una variante di CV viene salvata su disco (e nell'IndexedDB su web).

Punti da chiudere:
- Formato: JSON puro? JSON con schema versionato? Altro (YAML, TOML)? (Raccomandato: JSON versionato.)
- Nome/estensione del file (es. `.cv.json`, `.cvapp`).
- Presenza di un campo `schemaVersion` e strategia di migrazione tra versioni future dello schema.
- Come si serializzano date, enum, sezioni custom, riferimenti ad asset (foto).
- Un solo file per variante, o directory con file principale + asset? (Interseca con ticket 09.)
- Portabilità: un file esportato dovrebbe essere ri-importabile su un'altra istanza dell'app senza perdite.

Output atteso: schema JSON di esempio + regole di versioning.

## Vincoli decisi a monte

- Schema dati fisso e rich text = Markdown definiti in [ticket 01](01-schema-dati-cv.md). Considerare quel documento come input.
- Modello sezioni fisse+custom con `kind` immutabile e `displayTitle` modificabile definito in [ticket 02](02-sezioni-custom.md).

## Risoluzione

### Contenitore

- **Formato**: JSON.
- **Un solo file per variante**, con eventuali asset binari (foto profilo, futuri logo/firma) embed in **base64** dentro lo stesso JSON. Niente bundle, niente directory, niente file esterni referenziati per path.
- **Estensione**: `.cvapp`. Sotto il cofano è JSON standard, ma l'estensione custom segnala all'OS che è un documento dell'app (associazione per double-click) e lo distingue da JSON generici.
- **Nome del file**: nome della variante scelto dall'utente, senza prefissi/suffissi automatici (es. `Full-stack senior.cvapp`). Il nome è mutabile senza rompere l'identità logica.
- **Serializzazione a disco**: JSON **minified** (nessuna indentazione), UTF-8 senza BOM, newline `\n`.

### Identità e metadati

Ogni file `.cvapp` ha nella root:

- `id`: **UUID v4** generato alla creazione della variante, immutabile per tutta la vita del file. Su web funge da chiave IndexedDB naturale.
- `createdAt`, `updatedAt`: timestamp ISO-8601 in UTC. Usati per ordinamento "recenti" indipendente dal filesystem (che sul web non esiste).
- `variantName`: nome logico della variante (di norma coincide con il nome file, ma sopravvive a rename esterni dell'OS).

Su import di un `.cvapp` con `id` già presente localmente, l'app chiede all'utente: sovrascrivi la variante esistente **oppure** importa come nuova variante rigenerando l'`id`. Su duplicazione dall'app: rigenera sempre l'`id`.

### Versioning

- `schemaVersion`: **intero incrementale**, parte da `1`. Non semver.
- **Migrazione forward-only in-app**: all'apertura, se `schemaVersion < CURRENT`, l'app applica una catena di funzioni `migrate_N_to_N+1(json) -> json` in memoria. Il file su disco non viene toccato finché l'utente non salva; al primo save post-migrazione la nuova versione viene persistita.
- File con `schemaVersion > CURRENT` (app più vecchia che apre file da app più nuova): **rifiuto esplicito** con messaggio "aggiorna l'app". Nessun downgrade.
- Ogni bump di `schemaVersion` deve essere accompagnato in codebase da una funzione di migrazione documentata; changelog dello schema tracciato in un documento della spec, non nel file.
- **Campi sconosciuti in lettura → strict / errore.** L'unico canale legittimo per aggiungere campi è il bump di `schemaVersion` + migrazione. Un `.cvapp` con chiavi ignote è trattato come corrotto e rifiutato con messaggio azionabile.

### Struttura top-level

La root del JSON ha una lista ordinata omogenea `sections` invece di chiavi per-sezione. Questo modella nativamente le decisioni della `02` (ordine globale libero, sezioni fisse rimovibili, `displayTitle` per-variante) evitando la doppia sorgente di verità "chiavi presenti vs `sectionOrder`".

Ogni entry di `sections` ha forma:

```
{ "kind": "<enum canonico>", "displayTitle": "<stringa mostrata>", "data": <per-kind>, "id"?: "<uuid>" }
```

- `kind`: enum chiuso, snake_case ASCII. Valori: `anagrafica`, `contatti`, `sommario`, `esperienze`, `formazione`, `skill`, `lingue`, `certificazioni`, `custom`.
- `displayTitle`: stringa mostrata nel CV, editabile dall'utente. Vincolo di **unicità dei `displayTitle` all'interno della variante** (validato al save).
- `data`: forma variabile per `kind` (vedi sotto).
- `id`: **presente solo su `kind: "custom"`**, UUID v4 immutabile alla creazione. Le sezioni fisse sono identificate dal loro `kind` con vincolo di **unicità del `kind` per variante**.

### Forma di `data` per `kind`

- **Oggetto singleton** — `anagrafica`, `contatti`: `data` è un oggetto tipizzato secondo lo schema del ticket 01.
- **Lista di item** — `esperienze`, `formazione`, `lingue`, `certificazioni`: `data` è un array `[…]` di item, ognuno con un `id: UUID v4` immutabile alla creazione (stable key per reorder animato, undo/redo pulito, focus del form preservato).
- **Stringa Markdown** — `sommario`, `custom`: `data` è direttamente la stringa Markdown grezza (nessun preprocessing, nessun HTML derivato in cache).
- **Skill** — forma ibrida coerente con la `01`: `data = { "markdown": "…", "tags": ["…", "…"] }`.

### Valori atomici

- **Date**: mese+anno, stringa `"YYYY-MM"` (subset ISO-8601). Ordinabile lessicograficamente. Il parsing produce un value object `YearMonth` Dart che i template formattano a piacere.
- **"In corso"** (esperienza/formazione ancora attiva): campo booleano `current: true` sull'item, `endDate` assente o `null`. Nessuna sentinella tipo `"9999-12"`.
- **Enum**: stringhe canoniche snake_case ASCII, sempre. Il `displayTitle` visualizzato all'utente è un campo separato e localizzabile; l'enum è codice interno stabile.

### Asset store

- Root: `assets: { "<uuid>": { "mimeType": "…", "data": "<base64>" } }`. Chiave = UUID v4 stringa.
- Riferimento dai campi del CV via `{ "assetId": "<uuid>" }` (es. `anagrafica.foto`). Nessun path, nessun filename.
- Un `assetId` può essere referenziato da più campi/template senza duplicare il payload.
- **GC al save**: gli asset non più referenziati da nessun campo vengono rimossi dal file.
- Metadati per-asset nell'MVP: solo `mimeType` e `data`. Formati accettati, limiti di dimensione, ridimensionamento e regole di rendering PDF sono decisi nel [ticket 09](09-gestione-foto-e-asset.md).

### Portabilità

Un `.cvapp` esportato è un unico file autocontenuto: reimportabile su un'altra istanza dell'app (stessa versione o compatibile via migrazione) senza perdite. Il nome file può essere cambiato liberamente dall'utente prima o dopo l'import; l'identità logica vive nel campo `id` interno.

### Esempio minimale

```json
{
  "schemaVersion": 1,
  "id": "8f3c9a10-9b1c-4b2e-9b83-2c1b8d6e2f0a",
  "createdAt": "2026-08-22T15:00:00Z",
  "updatedAt": "2026-08-22T15:12:47Z",
  "variantName": "Full-stack senior",
  "sections": [
    {
      "kind": "anagrafica",
      "displayTitle": "Dati personali",
      "data": {
        "nome": "Federico",
        "cognome": "Laggiard",
        "foto": { "assetId": "b0e7c4d2-3a1f-4d9c-88a1-3fa1c6d0b2e2" }
      }
    },
    {
      "kind": "contatti",
      "displayTitle": "Contatti",
      "data": { "email": "me@example.com" }
    },
    {
      "kind": "sommario",
      "displayTitle": "Profilo",
      "data": "Sviluppatore full-stack con **10 anni** di esperienza…"
    },
    {
      "kind": "esperienze",
      "displayTitle": "Esperienze",
      "data": [
        {
          "id": "1c7a1b6e-2f3d-4a1b-9c0e-5d6e7f8a9b0c",
          "ruolo": "Senior Engineer",
          "azienda": "ACME",
          "startDate": "2023-05",
          "current": true,
          "descrizione": "- Progettato…\n- Guidato…"
        }
      ]
    },
    {
      "kind": "lingue",
      "displayTitle": "Lingue",
      "data": [
        { "id": "aa11…", "lingua": "Italiano", "livello": "c2" },
        { "id": "bb22…", "lingua": "English",  "livello": "c1" }
      ]
    },
    {
      "kind": "custom",
      "id": "d1e2f3a4-5b6c-7d8e-9f0a-1b2c3d4e5f60",
      "displayTitle": "Pubblicazioni",
      "data": "- *A framework for…*, IEEE 2024\n- *On the impact of…*, ACM 2023"
    }
  ],
  "assets": {
    "b0e7c4d2-3a1f-4d9c-88a1-3fa1c6d0b2e2": {
      "mimeType": "image/jpeg",
      "data": "/9j/4AAQSkZJRgABAQEAYABgAAD/…"
    }
  }
}
```

### Intersezioni con altri ticket

- **Ticket 04 (storage per piattaforma)** — ora sbloccato. Il layer astratto lavora su unità "un `.cvapp`", che su desktop/mobile è un file, su web è una entry IndexedDB con chiave = `id`.
- **Ticket 09 (foto e asset)** — asset store definito qui; restano da decidere formati accettati, ridimensionamento e regole di embed nel PDF di export.
- **Ticket 06 (scelta stack)** — `json_serializable` + `freezed` sono candidati naturali per generare i codec dei tipi Dart derivati da questo schema.
