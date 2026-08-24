# Template PDF MVP — wireframe e specifiche (draft rough per reazione)

Contesto: [ticket 08](../08-design-template.md). Stack di rendering: `pdf` + `printing` (ticket 06) → tutto è codice Dart che compone `pw.Widget`. Ogni template è una classe `CvTemplate` con lo stesso ingresso (l'oggetto CV già deserializzato dallo schema del [ticket 01](../01-schema-dati-cv.md)) e restituisce un `pw.Document`.

## Vincoli condivisi ai 3 template

- **Formato pagina**: A4 (210×297 mm) hard-coded nell'MVP. Letter (215.9×279.4 mm) è **fuori scope MVP → v2**: nessun campo di formato serializzato nel `.cvapp`, quando arriverà Letter si aggiungerà via schema migration ([ticket 03](../03-formato-file-cv.md)).
- **Margini**: 18 mm top/bottom, 16 mm left/right (Classico e Minimal). Moderno con banda laterale: 0 mm sul lato della banda, 14 mm sull'altro, 16 mm top/bottom.
- **Font**: solo font open-source embed-abili tramite `pw.Font.ttf()` da asset bundle Flutter, con supporto Latin Extended (accenti IT/EN, ES, DE, FR, PL). Serif: **EB Garamond** (SIL OFL). Sans: **Inter** (SIL OFL). Mono (per eventuali code fence in Markdown): **JetBrains Mono** (SIL OFL). Nessun font di sistema, tutto embed per riproducibilità cross-platform.
- **Ordine sezioni**: rispetta l'ordine serializzato in `sections[]` del `.cvapp` ([ticket 03](../03-formato-file-cv.md)). I template **non riordinano**: se l'utente ha portato Certificazioni sopra Formazione nell'editor, il template le renderizza in quell'ordine. L'ordine di default del file è quello del ticket 01 (1–8).
- **Sezioni fisse rimosse**: se assenti dal `sections[]`, il template le salta silenziosamente.
- **Sezioni custom**: renderizzate con lo stesso block-renderer Markdown usato per Sommario ([ticket 02](../02-sezioni-custom.md)), preceduto dal `displayTitle` come header di sezione nello stile del template.
- **Foto profilo**: opzionale ([ticket 09](../09-gestione-foto-e-asset.md)). Ogni template ha un layout "con foto" e un fallback "senza foto" (spazio riassorbito, non lasciato vuoto).
- **Multipagina**: `pw.MultiPage` di base. Header di pagina: nessuno sulla prima, dalla seconda in poi "Nome Cognome — pag. N di M" allineato alle regole tipografiche del template. Footer: sempre vuoto (MVP). Page break: mai spezzare l'header di una sezione dal suo primo item (`pw.Wrap` + `keepTogether` sulla coppia header+primoItem); item lunghi (una singola esperienza) possono spezzarsi a paragrafo.
- **Rendering Markdown**: subset condiviso — bold, italic, liste puntate/numerate, link (colore accent del template, sottolineati). Nessun heading Markdown dentro i campi (i field-level heading sono decisi dal template). Code fence renderizzato con `JetBrains Mono` in un box grigio molto tenue.
- **Contatti**: la lista `Link[]` renderizzata sempre come `label · url` (o solo icona+label se lo spazio è compresso, es. banda laterale Moderno).
- **Skill tag**: chip/pill piatti, senza livello (schema 01 non lo prevede).

---

## Template 1 — "Classico"

**Audience**: candidature formali, PA, banche/assicurazioni, ATS-heavy. Il template che *non attira attenzione al layout*: attira attenzione ai contenuti.

**Layout**: **singola colonna**, full-width. Nessuna banda, nessun colore di sfondo. Rispetta al 100% l'ordine di lettura top-down (ATS-friendly).

**Foto**: opzionale, in alto a destra dell'header Anagrafica, 28×36 mm (formato tessera). Se assente, l'header si espande a piena larghezza.

**Tipografia**:
- Titolo pagina (Nome Cognome): EB Garamond 22pt, weight regular, tracking leggermente aperto.
- Headline (titolo professionale da Anagrafica): EB Garamond 12pt italic, sotto il nome.
- Header di sezione: EB Garamond 13pt small-caps, weight semibold, sottolineatura hairline (0.5pt) piena larghezza sotto il titolo.
- Body: EB Garamond 10.5pt regular, interlinea 1.35.
- Meta (date, luogo, azienda): EB Garamond 10pt italic.

**Palette**: solo neri e grigi. Testo `#111111`. Meta `#555555`. Hairline `#888888`. Link `#1a1a1a` sottolineato (niente blu). Zero colori accent.

**Presentazione sezioni**:
- Anagrafica: nome grande centrato o allineato-sinistra, headline sotto, poi hairline di separazione.
- Contatti: riga singola sotto l'anagrafica, elementi separati da `·`, formato `email · tel · città · link[label]`.
- Sommario: paragrafo Markdown, nessun titolo di sezione (implicito dopo header anagrafica).
- Esperienze/Formazione/Certificazioni: per ogni item, riga 1 = `Ruolo — Azienda` in bold + `data inizio – data fine` allineato a destra; riga 2 = `luogo · modalità · tipo contratto` in meta italic; poi descrizione Markdown.
- Skill: chip inline (testo + bordino 0.5pt attorno, no fill), su una-tre righe di wrap; se c'è contenuto Markdown (campo principale), va sopra i chip.
- Lingue: tabellina 2 colonne — `Lingua` | `Livello CEFR (Certificazione)`, hairline di separazione fra righe.

**Multipagina**: header ripetuto da pag. 2 "Nome Cognome — pag. N/M" in EB Garamond 9pt italic in alto a destra.

**Wireframe (A4 verticale)**:
```
┌────────────────────────────────────────────────────────┐
│                                                        │
│   MARIO ROSSI                              ┌────────┐  │
│   Senior Backend Engineer                  │        │  │
│                                            │  foto  │  │
│   mario@example.com · +39 …  ·  Milano     │        │  │
│                                            └────────┘  │
│  ────────────────────────────────────────────────────  │
│                                                        │
│   Sommario paragrafo Markdown, testo scorre pieno-     │
│   larghezza, misura di riga ~90 caratteri.             │
│                                                        │
│   ESPERIENZE ─────────────────────────────────────────  │
│                                                        │
│   Senior Backend Engineer — Acme SpA   Mar 2022 – oggi │
│   Milano · ibrido · full-time                          │
│   • Ho progettato l'architettura del servizio X…       │
│   • Ho guidato la migrazione da…                       │
│                                                        │
│   Backend Engineer — Foo Srl           Gen 2020 – Feb  │
│   …                                                    │
│                                                        │
│   FORMAZIONE ─────────────────────────────────────────  │
│   …                                                    │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Template 2 — "Moderno"

**Audience**: ruoli tech, product, design, prodotto digitale in generale. Vuole comunicare cura visiva senza essere sopra le righe.

**Layout**: **due colonne asimmetriche** con **banda laterale sinistra** a sfondo colorato (larghezza 62 mm su A4, ~29% della pagina). La banda ospita Anagrafica (con foto), Contatti, Skill, Lingue. La colonna principale a destra (larghezza ~132 mm) ospita Sommario, Esperienze, Formazione, Certificazioni, sezioni custom.

**Foto**: nella banda, in alto, circolare (Ø 40 mm), con hairline chiaro attorno. Se assente, la banda inizia direttamente col nome.

**Tipografia**:
- Nome (banda): Inter 20pt semibold, colore accent-on-dark (bianco `#ffffff`).
- Headline (banda): Inter 10pt regular, `#e6e6e6`.
- Header di sezione banda: Inter 9pt uppercase tracking wide, colore `#c9d4de` (grigio-azzurro chiaro).
- Header di sezione colonna principale: Inter 12pt semibold, colore accent (v. palette), con barretta 3pt × 24 mm dello stesso colore a sinistra del titolo.
- Body: Inter 10pt regular, interlinea 1.4, `#1f2933` sulla colonna bianca, `#e6ecf1` sulla banda.
- Meta: Inter 9pt regular, `#5c6b7a` (bianco) / `#a4b1bd` (banda).

**Palette**: accent unico **`#2b6cb0`** (blu petrolio sobrio). Banda laterale sfondo `#1f2d3d` (blu notte scuro), testo chiaro. Colonna principale sfondo bianco `#ffffff`, testo `#1f2933`. Link nell'accent, non sottolineati (accent + weight medium bastano).

**Presentazione sezioni**:
- **Banda (sinistra)**:
  - Anagrafica: foto, nome, headline; poi Contatti sotto un piccolo `CONTATTI`.
  - Contatti: una riga per campo, icona (glifo geometrico monocromo) + valore. Link mostrati come `label` con icona URL.
  - Skill: se ci sono tag, chip pieni (fill accent, testo bianco, radius 6pt). Se c'è contenuto Markdown (campo principale), va sopra i chip. Se molto denso, chip scendono a piena larghezza banda.
  - Lingue: una riga per lingua — `Lingua` bold + livello CEFR meta, sotto barra 4pt riempita in proporzione (A1=1/6, C2/Madrelingua=6/6).
- **Colonna principale (destra)**:
  - Sommario: paragrafo Markdown senza header, come "intro" della colonna.
  - Esperienze/Formazione/Certificazioni: per ogni item, `Ruolo` bold 11pt + `— Azienda` regular 11pt sulla stessa riga, `data inizio – data fine · luogo · modalità` meta sotto, descrizione Markdown; separator hairline `#e2e8f0` fra item consecutivi.
  - Sezioni custom: header di sezione stile colonna principale + block Markdown.

**Multipagina**: banda **solo sulla prima pagina**. Da pag. 2 in poi la colonna principale si espande a piena larghezza (margini 16 mm come il Classico) e prosegue a singola colonna. Header di pagina in colonna principale da pag. 2: "Nome Cognome — pag. N/M" in Inter 9pt, `#5c6b7a`, in alto a destra. **Costo**: leggera discontinuità visiva del "brand" fra pag. 1 e pag. 2+; **guadagno**: nessuno spreco di ~29% di superficie a ripetere contenuto identico su ogni pagina, CV lunghi restano leggibili.

**Wireframe (A4 verticale)**:
```
┌──────────────┬─────────────────────────────────────────┐
│░░░░░░░░░░░░░░│                                         │
│░░░ ⬤ foto ░░░│  Sommario paragrafo Markdown, testo     │
│░░░░░░░░░░░░░░│  scorre nella colonna principale.       │
│░ Mario Rossi │                                         │
│░ Senior Back │  ▍ESPERIENZE                            │
│░              │                                         │
│░ CONTATTI    │  Senior Backend Engineer — Acme SpA     │
│░ ✉ email     │  Mar 2022 – oggi · Milano · ibrido      │
│░ ☎ tel       │  • …                                    │
│░ 📍 Milano   │                                         │
│░ ↗ github    │  Backend Engineer — Foo Srl             │
│░              │  Gen 2020 – Feb 2022 · Milano · remoto  │
│░ SKILL       │  • …                                    │
│░ [Go][K8s]   │                                         │
│░ [Postgres]  │  ▍FORMAZIONE                            │
│░              │  …                                     │
│░ LINGUE      │                                         │
│░ Italiano    │                                         │
│░ ████████ C2 │                                         │
│░ Inglese     │                                         │
│░ ██████   B2 │                                         │
└──────────────┴─────────────────────────────────────────┘
```

---

## Template 3 — "Minimal"

**Audience**: profili senior/tecnici che vogliono comunicare "il contenuto parla da sé"; consulenza, ricerca, ruoli creativi che preferiscono un tono editoriale. Zero colori, zero decorazioni, solo tipografia.

**Layout**: **singola colonna**, ma con **cassa più stretta** dei margini (misura di riga ~72 caratteri) → margini laterali generosi (28 mm left/right), 22 mm top/bottom. Header di sezione allineati alla colonna, non alla pagina. Nessuna hairline, nessun bordo.

**Foto**: **assente per design**. Anche se il CV ha `fotoProfiloAssetId`, questo template la ignora (non è una degradazione — è una scelta stilistica).

**Tipografia**:
- Nome: Inter 16pt regular, letter-spacing 0.02em (lievemente aperto). **Non è il pezzo grosso della pagina** — il template deprime la gerarchia dell'header.
- Headline: Inter 10.5pt regular, colore meta.
- Contatti: Inter 9pt regular, riga singola sotto headline, elementi separati da `  ·  ` (2 spazi).
- Header di sezione: Inter 9.5pt uppercase tracking wide (`letter-spacing 0.15em`), colore meta, **niente sottolineatura, niente barra**. Solo spazio verticale (18pt) sopra come separazione.
- Body: EB Garamond 10.5pt regular, interlinea 1.5. **Miscela intenzionale sans (label) + serif (body)** per tono editoriale.
- Meta: EB Garamond 10pt italic, `#666666`.

**Palette**: nero puro `#000000` per il body, `#666666` per meta e header di sezione, `#333333` per il nome. Link `#000000` con underline hairline. Nessun colore accent. Sfondo bianco puro.

**Presentazione sezioni**:
- Anagrafica: nome + headline + contatti su 3 righe strette, allineate a sinistra. Nessun elemento grafico. Spazio verticale 24pt sotto.
- Sommario: paragrafo Markdown, senza header, corpo full-column.
- Esperienze/Formazione/Certificazioni: item con `Ruolo — Azienda` in bold body, date meta a destra sulla stessa riga (giustificato con leader spaces), riga meta secondaria `luogo · modalità`, descrizione Markdown sotto. Fra item, solo 12pt di spazio (niente hairline).
- Skill: chip **tipografici** (nessun bordo, solo testo separato da ` · `). Es. `Go · Kubernetes · Postgres · gRPC`. Se c'è Markdown, va sopra come paragrafo.
- Lingue: `Lingua — Livello CEFR (certificazione)` una per riga, corpo body.

**Multipagina**: nessun header ripetuto (design minimalista). Numero pagina in basso a destra da pag. 2: `— 2 —` in Inter 8.5pt, `#666666`. Header sezione mai orfano (`keepTogether` con primo item).

**Wireframe (A4 verticale)**:
```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│      Mario Rossi                                       │
│      Senior Backend Engineer                           │
│      mario@example.com  ·  +39 …  ·  Milano            │
│                                                        │
│                                                        │
│      Sommario paragrafo con misura di riga stretta,    │
│      corpo serif, dà un tono editoriale.               │
│                                                        │
│                                                        │
│      ESPERIENZE                                        │
│                                                        │
│      Senior Backend Engineer — Acme SpA                │
│                                     Mar 2022 – oggi    │
│      Milano · ibrido                                   │
│      Ho progettato l'architettura del servizio X…      │
│                                                        │
│      Backend Engineer — Foo Srl                        │
│                              Gen 2020 – Feb 2022       │
│      …                                                 │
│                                                        │
│      FORMAZIONE                                        │
│      …                                                 │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Note tecniche trasversali (per l'implementazione post-MVP)

- Ogni template esporta una `thumbnail` statica (PNG generato una tantum in `assets/templates/<id>.png`) usata dallo `Anteprima` (ticket 07).
- Font TTF embed in `assets/fonts/`: `EBGaramond-Regular.ttf`, `EBGaramond-Italic.ttf`, `EBGaramond-SemiBold.ttf`, `Inter-Regular.ttf`, `Inter-SemiBold.ttf`, `JetBrainsMono-Regular.ttf`. Bundle stimato ~1.2 MB, accettabile (Latin subset).
- Nessun template dipende da campi opzionali dello schema: ogni campo assente si "sgretola" (foto assente, luogo assente, ecc.) senza lasciare buchi visibili.
