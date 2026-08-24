# Design dei 2–3 template di export PDF

Type: prototype
Status: closed
Assignee: wayfinder-agent
Blocked by: 01

## Question

Definire concretamente i **2–3 template** hard-coded che l'MVP offre per l'export PDF.

Punti da chiudere per ciascun template:
- Nome e "audience" (es. "Classico", "Moderno a colonne", "Minimal").
- Layout ad alto livello: singola colonna / doppia colonna / con banda laterale; con foto o senza.
- Tipografia (famiglie di font open-source utilizzabili) e palette colori.
- Ordine e presentazione delle sezioni fisse.
- Come renderizza sezioni custom (interseca con ticket 02).
- Comportamento su multi-pagina (page break, header/footer, numerazione).
- Vincoli fissi: formato A4 e/o Letter; margini; supporto lingue con caratteri estesi.

Output atteso: file linkato con outline visivo/wireframe per ognuno dei template scelti.

## Vincoli decisi a monte

- Schema dati fisso e rich text = Markdown definiti in [ticket 01](01-schema-dati-cv.md). Considerare quel documento come input.

## Risoluzione

**3 template hard-coded** nell'MVP: **Classico**, **Moderno**, **Minimal** — coprono il mix "formale ATS-friendly / design moderno / editoriale tipografico". Ogni template è una classe `CvTemplate` che riceve il CV deserializzato e produce un `pw.Document` via `pdf` + `printing` ([ticket 06](06-scelta-stack-flutter.md)); tutti condividono lo stesso block-renderer Markdown (subset: bold, italic, liste, link) riusato per Sommario e sezioni custom, coerente col [ticket 02](02-sezioni-custom.md).

**Vincoli condivisi**:
- **Formato pagina**: A4 hard-coded. Letter (215.9×279.4 mm, nordamericano) esplicitamente **fuori scope MVP → v2**; nessun campo `pageFormat` nel `.cvapp` ora, si aggiungerà via schema migration.
- **Font open-source**: EB Garamond (serif, SIL OFL), Inter (sans, SIL OFL), JetBrains Mono (mono per code fence, SIL OFL). Tutti embed via `pw.Font.ttf()` da `assets/fonts/`, subset Latin Extended per accenti IT/EN/ES/DE/FR/PL. Bundle stimato ~1.2 MB.
- **Ordine sezioni**: rispetta l'ordine serializzato in `sections[]` del `.cvapp` ([ticket 03](03-formato-file-cv.md)) — i template non riordinano. Sezioni fisse rimosse dallo scroll dell'editor sono saltate silenziosamente.
- **Foto profilo** ([ticket 09](09-gestione-foto-e-asset.md)): ogni template ha layout "con foto" e fallback "senza foto" senza buchi. Eccezione stilistica: il **Minimal ignora sempre la foto per design**, anche se `fotoProfiloAssetId` è presente.
- **Multipagina**: `pw.MultiPage` di base; `keepTogether` su header sezione + primo item (niente header orfani); footer sempre vuoto; header di pagina da pag. 2 in poi con "Nome Cognome — pag. N/M" nello stile del template.

**Template 1 — Classico**: audience ATS/formale (PA, banche, assicurazioni). Singola colonna full-width, EB Garamond, palette solo neri/grigi, header di sezione small-caps sottolineati hairline. Foto opzionale in alto a destra 28×36 mm. Margini 18/16 mm. Contatti su riga singola sotto anagrafica separati da `·`. Skill = chip con bordino, no fill. Lingue = tabellina 2 colonne.

**Template 2 — Moderno**: audience tech/product/design. Due colonne asimmetriche, **banda laterale sinistra `#1f2d3d` (62 mm, ~29%)** su fondo scuro con foto circolare Ø40mm + contatti + skill + lingue; colonna principale bianca con Sommario + Esperienze + Formazione + Certificazioni + custom. Font Inter, accent `#2b6cb0`. **Banda solo sulla prima pagina**: da pag. 2 in poi la colonna principale si espande a piena larghezza (margini 16 mm) per non sprecare superficie su contenuto identico ripetuto. Skill = chip pieni radius 6pt. Lingue = barra graduata proporzionale al livello CEFR.

**Template 3 — Minimal**: audience senior/consulenza/creativi. Singola colonna stretta (misura ~72 caratteri, margini 28/22 mm), miscela intenzionale Inter (label uppercase tracking wide) + EB Garamond (body serif) per tono editoriale. Zero colori, zero decorazioni grafiche, gerarchia dell'header depressa (nome 16pt non è "il pezzo grosso"). Header di sezione senza sottolineatura né barra, solo spazio verticale. Skill = chip tipografici (`Go · Kubernetes · Postgres`, nessun bordo). Numero pagina in basso a destra da pag. 2 (`— 2 —`).

Wireframe testuali completi + specifiche tipografiche/palette/multipagina per template: [assets/08-design-template-wireframes.md](assets/08-design-template-wireframes.md).
