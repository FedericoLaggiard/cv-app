# UX editor CV — wireframe testuali e outline schermate

Prototipo del ticket [07 — UX dell'editor del CV](../07-ux-editor.md).

Coerente con: schema dati (ticket 01), sezioni custom (02), formato file (03), storage per piattaforma (04), stack Flutter (06), foto/asset (09), euristiche import PDF (13).

---

## 0. Sintesi delle decisioni UX

| Tema | Decisione |
|---|---|
| Piattaforma primaria | Desktop + Web paritari (layout largo); mobile trattato a parte |
| Navigazione tra sezioni (largo) | **Scroll unico** verticale in colonna centrale + **sidebar-indice** cliccabile a sinistra (jump-to, non filtra) |
| Voci sezioni-lista | **Sempre espanse** a piena altezza nel flusso, nessun collapse |
| Sezioni (intere) | **Collassabili** via chevron nell'header (click su header o chevron); default espanse; azioni `Comprimi tutte` / `Espandi tutte` nella sidebar/bottom-sheet; jump-to dall'indice espande automaticamente; stato **non** serializzato in `.cvapp` |
| Editing rich text | `super_editor` WYSIWYG (ticket 06); **toolbar sempre visibile in cima al campo attivo** |
| Riordino sezioni + voci | **Drag handle** primario + **menu contestuale** ("Sposta su/giù/in cima/in fondo") come fallback accessibile |
| Aggiunta sezione custom | Bottone `+ Aggiungi sezione` **sia** in fondo allo scroll **sia** nella sidebar-indice |
| Aggiunta voce lista | Bottone `+ Aggiungi <voce>` **sia** nell'header della sezione **sia** in coda alla lista |
| Live preview PDF | **Route/schermata a pagina piena**, on-demand; si apre col pulsante `Anteprima` in top bar |
| Cambio template | Selector con thumbnail nella toolbar in cima alla schermata anteprima; non modifica i dati |
| Validazione obbligatori | **Marker soft**: badge ⚠ nell'indice + header sezione + header voce; **nessun blocco**; riepilogo dei mancanti all'export PDF |
| Salvataggio | Auto-save con debounce ~800ms (ticket 04); indicatore "Salvato" in top bar |
| Mobile | Indice = **bottom sheet** a comparsa; anteprima = **pagina piena** (stessa forma del desktop); editor a piena larghezza |
| Avvio app | **Schermata Libreria** con card variante + CTA `Nuova` (vuota / da PDF / duplica) |

Fuori dal perimetro di questo ticket (rimangono in **Non ancora specificato**): UX di gestione varianti nel dettaglio (rinomina, cancellazione, duplicazione), preview live in-editor, onboarding step-by-step del primo utente, i18n del CV.

---

## 1. Mappa delle schermate

```
┌─ App
├─ Libreria                       (root, sempre punto d'ingresso)
│  ├─ Nuova variante → Editor (variante vuota)
│  ├─ Importa da PDF → Editor (variante pre-riempita, badge "Import parziale")
│  ├─ Duplica variante → Editor (copia con nome incrementato)
│  └─ Apri variante → Editor
├─ Editor (largo: 2 colonne, mobile: 1 colonna)
│  ├─ Anteprima PDF   (route/schermata a pagina piena — stessa forma su largo e mobile)
│  └─ Esporta PDF     (dialog di destinazione + file picker)
└─ Impostazioni       (minimale MVP: lingua UI, versione, path libreria)
```

Nessuna schermata di "login", "sync", "profilo utente" (front-end only, ticket 04).

---

## 2. Schermata Libreria — layout largo

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  CV app                                              [⚙ Impostazioni]  [?]   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Le tue varianti CV                                                         │
│                                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   ┌──────────────┐    │
│   │ ➕ Nuova      │  │  Backend Sr  │  │  Frontend Sr │   │  Consulenza  │    │
│   │ variante     │  │  aggiornato  │  │  aggiornato  │   │  aggiornato  │    │
│   │              │  │  ieri        │  │  3 giorni fa │   │  2 sett fa   │    │
│   │  [▾]         │  │  [Apri] [⋯]  │  │  [Apri] [⋯]  │   │  [Apri] [⋯]  │    │
│   └──────────────┘  └──────────────┘  └──────────────┘   └──────────────┘    │
│                                                                              │
│   ┌──────────────┐                                                           │
│   │  Backend Jr  │                                                           │
│   │  ...         │                                                           │
│   └──────────────┘                                                           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Card "Nuova variante"** apre un menu con tre voci:
  - `Da zero` → crea variante vuota e apre Editor
  - `Da PDF esistente…` → file picker → auto-import (ticket 10/13) → Editor con badge "Import da PDF"
  - `Duplica una variante…` → dialog con lista varianti esistenti → Editor con copia
- **Card variante**: nome variante (`variantName`) + "aggiornato <relativo>" + `[Apri]` primario + `[⋯]` menu (Duplica, Rinomina, Esporta `.cvapp`, Esporta PDF…, Elimina).
- Stato vuoto (libreria senza varianti): unico blocco centrale con i tre CTA verticali.
- Su desktop nativo compare anche `[Apri file .cvapp esterno…]` in top bar (equivalente al doppio-click di sistema — ticket 04).

Stato vuoto:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  CV app                                                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                       Non hai ancora nessuna variante.                       │
│                                                                              │
│                       ┌──────────────────────────────┐                       │
│                       │  ✦ Crea CV da zero           │                       │
│                       └──────────────────────────────┘                       │
│                       ┌──────────────────────────────┐                       │
│                       │  ⇪  Importa da PDF esistente │                       │
│                       └──────────────────────────────┘                       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Editor — layout largo (desktop + web)

Due colonne fisse. Nessuna terza colonna: l'anteprima è una **route/schermata a pagina piena** on-demand (§4).

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  ← Libreria │  Backend Sr                     Salvato ✓  │ [Anteprima] [Esporta ▾]│
├────────────────────────┬─────────────────────────────────────────────────────────┤
│  INDICE                │  EDITOR (scroll unico)                                  │
│                        │                                                         │
│  ⋮⋮ Anagrafica       ⚠ │  ┌─ ⋮⋮ ▾ Anagrafica ─────────────────────────  [⚠] [⋯]┐│
│  ⋮⋮ Contatti           │  │                                                     ││
│  ⋮⋮ Sommario           │  │  Nome*        [ Federico            ]               ││
│  ⋮⋮ Esperienze     ⚠(2)│  │  Cognome*     [ Laggiard            ]               ││
│  ⋮⋮ Formazione         │  │  Foto profilo [ 📷 Carica…  ] [Rimuovi]              ││
│  ⋮⋮ Skill              │  │                                                     ││
│  ⋮⋮ Lingue             │  └─────────────────────────────────────────────────────┘│
│  ⋮⋮ Certificazioni     │                                                         │
│  ⋮⋮ Progetti (custom)  │  ┌─ Contatti ──────────────────────────────────  ⋮⋮ [⋯]┐│
│                        │  │  Email        [                     ]                ││
│  [+ Aggiungi sezione]  │  │  Telefono     [                     ]                ││
│  Comprimi tutte        │  │  Link                                                ││
│  Espandi tutte         │  │   1  linkedin.com/in/…       [⋮⋮] [🗑]              ││
│                        │  │   2  github.com/…            [⋮⋮] [🗑]              ││
│                        │  │  [+ Aggiungi link]                                   ││
│                        │  └─────────────────────────────────────────────────────┘│
│                        │                                                         │
│                        │  ┌─ Sommario ──────────────────────────────────  ⋮⋮ [⋯]┐│
│                        │  │ [B] [I] [H2] [•] [1.] [🔗]  ← toolbar Markdown       ││
│                        │  │  ┌───────────────────────────────────────────────┐  ││
│                        │  │  │  Ingegnere backend con ...                    │  ││
│                        │  │  │                                               │  ││
│                        │  │  └───────────────────────────────────────────────┘  ││
│                        │  └─────────────────────────────────────────────────────┘│
│                        │                                                         │
│                        │  ┌─ Esperienze ────────────────────────────────  ⋮⋮ [⋯]┐│
│                        │  │  [+ Aggiungi esperienza]                             ││
│                        │  │                                                     ││
│                        │  │  ⋮⋮  Backend engineer · Acme  ·  gen 2022–oggi ⚠ [⋯]││
│                        │  │      Ruolo*       [ Backend engineer   ]            ││
│                        │  │      Azienda*     [ Acme               ]            ││
│                        │  │      Località     [ Milano             ]            ││
│                        │  │      Data inizio* [ 01/2022  ] Data fine [ ☐ In corso]││
│                        │  │      Descrizione (Markdown)                          ││
│                        │  │      [B][I][H2][•][1.][🔗]                           ││
│                        │  │      ┌─────────────────────────────────────────┐    ││
│                        │  │      │ - Rifattorizzato il servizio …          │    ││
│                        │  │      └─────────────────────────────────────────┘    ││
│                        │  │                                                     ││
│                        │  │  ⋮⋮  Junior dev · BetaCorp  ·  giu 2020–dic 2021 [⋯]││
│                        │  │      ...  (voce espansa a piena altezza)             ││
│                        │  │                                                     ││
│                        │  │  [+ Aggiungi esperienza]                             ││
│                        │  └─────────────────────────────────────────────────────┘│
│                        │                                                         │
│                        │  … (Formazione, Skill, Lingue, Certificazioni,          │
│                        │       Progetti custom, ecc.)                            │
│                        │                                                         │
│                        │  ┌──────────────────────────────────────────────────┐  │
│                        │  │  [+ Aggiungi sezione]                            │  │
│                        │  └──────────────────────────────────────────────────┘  │
└────────────────────────┴─────────────────────────────────────────────────────────┘
```

Sezione **collassata** (esempio):

```
┌─ ⋮⋮ ▸ Esperienze ─────────────────────────────────────  [⚠(2)] [⋯]┐
└──────────────────────────────────────────────────────────────────┘
```

Il chevron diventa `▸`, il body scompare, l'header resta cliccabile (chevron o intero header) per riespandere. Il badge ⚠ resta visibile per non nascondere obbligatori mancanti dentro sezioni chiuse.

### Elementi ricorrenti

- **Header sezione**: `⋮⋮ ▾ <displayTitle>  [⚠]  [⋯]`
  - `⋮⋮` drag handle per riordinare la sezione nell'ordine globale.
  - `▾` chevron di collapse/expand della sezione (`▸` quando collassata). Click sul chevron **o sull'intero header** alterna lo stato; il drag handle e il menu `[⋯]` restano isolati (`stopPropagation`) per non triggerare il collapse per errore.
  - `[⋯]` menu contestuale: `Rinomina`, `Sposta su`, `Sposta giù`, `Sposta in cima`, `Sposta in fondo`, `Rimuovi sezione`.
  - Il `displayTitle` è editabile inline: click sul titolo → input (l'attivazione dell'input non deve triggerare il collapse).
  - Quando la sezione è collassata, l'header resta visibile (badge ⚠ incluso) e il body scompare. Nessuna animazione richiesta nell'MVP.
- **Header voce (dentro sezione-lista)**: `⋮⋮ <riassunto denso> [⚠] [⋯]`
  - Il riassunto è calcolato da: ruolo+azienda+range date (Esperienze), titolo+ente+data (Formazione), lingua+livello (Lingue), nome+ente (Certificazioni).
  - Serve solo come "targhetta" all'inizio della voce; il form è **sempre visibile sotto** (non c'è collapse per voce).
- **Badge ⚠**: appare nell'indice a destra del nome sezione, sull'header della sezione, e sull'header della singola voce, se ci sono campi obbligatori vuoti. Tooltip: `2 campi mancanti`.
- **Top bar**:
  - `← Libreria` chiude l'editor (auto-save già salvato).
  - Nome variante editabile inline.
  - Indicatore `Salvato ✓` / `Salvataggio…` / `⚠ Errore salvataggio` (retry).
  - `[Anteprima]` → apre la schermata Anteprima PDF a pagina piena (§4).
  - `[Esporta ▾]` → menu: `Esporta PDF…`, `Esporta .cvapp…`, `Stampa…`.
- **Sidebar-indice**:
  - Riflette l'ordine globale delle sezioni; drag handle a ciascuna voce; click su una riga → scrolla la centrale a quella sezione, **espandendola automaticamente se collassata**.
  - Bottone `[+ Aggiungi sezione]` in fondo (duplicato di quello nella centrale).
  - Sotto, coppia di link testuali `Comprimi tutte` / `Espandi tutte` che agiscono su tutte le sezioni della variante corrente.
  - Larghezza fissa ~220px; se la finestra è < 900px la sidebar diventa un bottom sheet a comparsa (hamburger nella top bar) — vedi §5 mobile.

### Interazione "+ Aggiungi sezione"

Un unico dialog, invocato da entrambi i punti di ingresso:

```
┌─ Aggiungi sezione ─────────────────────────────┐
│                                                │
│  Sezioni standard (non presenti)               │
│    ○ Sommario                                  │
│    ○ Lingue                                    │
│                                                │
│  ─────────────                                 │
│    ● Sezione personalizzata                    │
│      Titolo:  [ Progetti open source     ]     │
│                                                │
│                          [Annulla]  [Aggiungi] │
└────────────────────────────────────────────────┘
```

La lista "Sezioni standard (non presenti)" mostra i `kind` fissi rimossi dalla variante corrente (ticket 02), così l'utente può ripristinarli con un click. La sezione personalizzata è sempre l'ultima opzione e chiede solo il `displayTitle`.

### Rimozione sezione fissa

Il menu `[⋯]` di una sezione fissa espone `Rimuovi sezione` (ticket 02: le sezioni fisse sono rimovibili). Conferma con dialog: `Rimuovere "Contatti"? I dati verranno persi. La sezione può essere riaggiunta ma i dati non torneranno.` Nessun undo (accettato per MVP; il file su disco viene sovrascritto all'auto-save).

### Comportamento drag

- Solo il **drag handle** `⋮⋮` avvia il drag (non l'intera card → evita conflitti col text editing).
- Feedback: la sezione/voce trascinata diventa semi-trasparente; una barra colorata segna il punto di drop.
- Il menu contestuale `[⋯]` funziona in parallelo per chi non usa il puntatore.

---

## 4. Schermata Anteprima PDF (layout largo)

Route/schermata a **pagina piena** che rimpiazza l'editor. Si torna all'editor con `← Editor` in top bar. Stessa forma su desktop e mobile — questa è la scelta di §5, riflessa qui.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  ← Editor  │  Anteprima — Backend Sr                        [Esporta PDF con Modern] │
├──────────────────────────────────────────────────────────────────────────────────┤
│  Template: ┌─Classic─┐ ┌─Modern─┐ ┌─Compact─┐    ⚠ Anteprima non aggiornata [Rigenera] │
│            │         │ │  ▓▓▓   │ │         │                                    │
│            └─────────┘ └─────────┘ └─────────┘                                    │
│              selezionato                                                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                    ┌──────────────────────────────────────┐                      │
│                    │                                      │                      │
│                    │   <foglio A4 centrato, pag. 1/N>     │                      │
│                    │   <rendering del PDF, zoomabile>     │                      │
│                    │                                      │                      │
│                    │                                      │                      │
│                    └──────────────────────────────────────┘                      │
│                                                                                  │
│              Pagina 1 / 2   [◀][▶]   [Zoom −][100%][+]                           │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- La schermata **rimpiazza** l'editor: nessun overlay, nessuno split, nessun editor sotto. L'auto-save dell'editor è già andato a buon fine prima di navigare.
- Le **thumbnail template** in toolbar mostrano una miniatura statica per identificare il layout senza rerender.
- Cambiare template **non modifica i dati** — cambia solo il renderer usato per l'anteprima (ticket 08 fisserà i template concreti).
- Il pulsante `Esporta PDF con <template>` in top bar è pre-configurato col template scelto nell'anteprima; è il gemello del menu `Esporta ▾` della top bar dell'editor.
- La rigenerazione della preview è **manuale**: se prima di navigare l'utente ha appena editato, o se torna in editor, edita e rientra, il banner `Anteprima non aggiornata [Rigenera]` compare finché non si preme rigenera. Motivo: rirender di ogni tasto sarebbe costoso e la scelta esplicita è "on-demand, non live".

---

## 5. Esporta PDF

Flusso lineare:

1. Utente preme `Esporta PDF…` (top bar dell'editor o della schermata anteprima).
2. Se il template è ambiguo (nessuno scelto di recente) → dialog `Scegli template` con thumbnail (stesse della schermata anteprima).
3. Validazione: se ci sono campi obbligatori mancanti, dialog di riepilogo:

    ```
    ┌─ Campi obbligatori mancanti ────────────────┐
    │                                             │
    │  Puoi esportare comunque, ma il PDF conterrà│
    │  spazi vuoti in questi punti:               │
    │                                             │
    │  • Anagrafica → Cognome                     │
    │  • Esperienze → Backend engineer · Acme →   │
    │      Data inizio                            │
    │  • Esperienze → nuova voce → Ruolo, Azienda │
    │                                             │
    │  [Torna a compilare]  [Esporta comunque]   │
    └─────────────────────────────────────────────┘
    ```

4. Se prosegue → **file picker** di sistema (`file_picker.saveFile()` desktop; `share_plus` mobile/Web — ticket 06) con default `<variantName>.pdf`.
5. Nessuna schermata di "conferma esportazione" post-save: toast `Esportato in <path>` con azione `Mostra nel Finder` (desktop) o nulla (Web).

---

## 6. Editor — layout mobile (portrait)

```
┌────────────────────────────┐
│ ☰   Backend Sr    ⋯   👁 │  ← top bar: hamburger (indice), nome, menu, anteprima
├────────────────────────────┤
│  Salvato ✓                │
│                            │
│ ┌─ Anagrafica ──── ⚠ ─┐   │
│ │ Nome*  [Federico  ]│    │
│ │ Cogn.* [Laggiard  ]│    │
│ │ Foto   [📷 Carica…]│    │
│ └────────────────────┘    │
│                            │
│ ┌─ Contatti ──────────┐   │
│ │ Email  [           ]│   │
│ │ Tel    [           ]│   │
│ │ Link                │   │
│ │  1 …          [⋮⋮]  │   │
│ │  [+ link]           │   │
│ └────────────────────┘    │
│                            │
│ ┌─ Sommario ──────────┐   │
│ │ [B][I][H2][•][🔗]    │   │
│ │ ┌───────────────┐  │   │
│ │ │ Ingegnere ... │  │   │
│ │ └───────────────┘  │   │
│ └────────────────────┘    │
│                            │
│ ┌─ Esperienze ────────┐   │
│ │ [+ Esperienza]      │   │
│ │ ⋮⋮ Backend · Acme  │   │
│ │    (voce espansa)   │   │
│ │ ...                 │   │
│ └────────────────────┘    │
│                            │
│  [+ Aggiungi sezione]     │
└────────────────────────────┘
```

### Indice come bottom sheet

Tap sull'hamburger (o swipe up dal bordo inferiore) apre un bottom sheet a metà schermo con la lista sezioni (badge ⚠, drag handle, jump-to). Il bottom sheet copre l'editor ma non lo chiude; tap fuori o swipe down lo chiude. L'header del bottom sheet ospita anche i controlli `Comprimi tutte` / `Espandi tutte` come sul largo. Tap su una voce dell'indice chiude il bottom sheet, **espande la sezione se collassata**, e scrolla in cima alla sezione.

```
┌────────────────────────────┐
│  editor sottostante         │
│  ── — — — — — — — — — —    │
├────────────────────────────┤
│  Sezioni  [Comprimi][Espandi] │
│                            │
│  ⋮⋮ Anagrafica         ⚠  │
│  ⋮⋮ Contatti              │
│  ⋮⋮ Sommario              │
│  ⋮⋮ Esperienze        ⚠(2)│
│  ⋮⋮ Formazione            │
│  ⋮⋮ Skill                 │
│  ⋮⋮ Lingue                │
│  ⋮⋮ Certificazioni        │
│  ⋮⋮ Progetti (custom)     │
│                            │
│  [+ Aggiungi sezione]      │
└────────────────────────────┘
```

### Anteprima come route piena

Tap sull'icona 👁 nella top bar naviga a una route **`/preview`** dedicata. Su mobile è **la stessa forma del desktop** (§4): route piena, non split, non drawer. Layout della route:

```
┌────────────────────────────┐
│ ←  Anteprima Backend Sr    │
├────────────────────────────┤
│ Template: [Classic ▼]      │
│                            │
│ ┌────────────────────────┐ │
│ │                        │ │
│ │   <PDF fullscreen>     │ │
│ │                        │ │
│ └────────────────────────┘ │
│                            │
│ Pag 1/2  ◀ ▶     [Esporta] │
└────────────────────────────┘
```

### Drag su mobile

Il drag handle rimane funzionante ma richiede **long-press → drag** (pattern iOS/Android standard) per non conflitasse con lo scroll. Il menu contestuale `[⋯]` diventa il canale primario per riordinare su mobile.

### Toolbar Markdown su mobile

Fissata **sopra la tastiera software** (non in cima al campo) quando il campo è in focus, così resta raggiungibile col pollice. Fuori focus scompare.

---

## 7. Casi limite

- **Import da PDF con badge**: dopo `Nuova → Da PDF`, l'editor si apre con un banner arancione in testa allo scroll: `Import da PDF: alcune sezioni possono essere state riempite parzialmente. Controlla e correggi. [Ho capito]`. Coerente con ticket 10 (auto-import puro, correzione = editor normale).
- **Foto non caricata / rimossa**: campo Anagrafica mostra placeholder generico; nessun errore (ticket 09: foto opzionale).
- **Foto oltre 500 KB dopo normalizzazione**: dialog `Immagine troppo grande anche dopo compressione. Scegli un'altra foto.` (ticket 09).
- **File `.cvapp` corrotto** aperto da libreria: card variante mostra badge `⚠ corrotta` con azioni `Esporta grezzo`, `Elimina` (ticket 04); non si apre nell'editor.
- **Auto-save fallito** (disk full, permessi): indicatore top bar diventa `⚠ Errore salvataggio [Riprova]`; nessun blocco dell'editor.
- **Sezione fissa rimossa e riaggiunta**: dialog aggiungi mostra la sezione tra "standard non presenti", ma i dati non tornano — questo è documentato nella conferma di rimozione.
- **Ordine globale con sola una sezione**: drag handle rimane visibile ma inerte; nessuna gestione speciale.

---

## 8. Cose deliberatamente **non** in questo prototipo (rimandate)

- Design visivo dei template PDF → ticket 08.
- Gestione varianti nel dettaglio (rinomina, cancellazione, duplicazione con conferma) → aggiornerà "Non ancora specificato".
- Preview live continuo in-editor → esplicitamente scartato (route on-demand, non live).
- Onboarding step-by-step primo utente → aggiornerà "Non ancora specificato".
- i18n del contenuto CV (CV in più lingue) → aggiornerà "Non ancora specificato".
- Impostazioni oltre le minime (lingua UI, path libreria) → fuori scope MVP.
