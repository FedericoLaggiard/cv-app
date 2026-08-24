# Testing E2E dell'app Flutter (mobile + web + desktop) pilotato da agente AI

Type: grill-with-docs
Status: closed

## Question

Definire l'infrastruttura di **test end-to-end** dell'app CV che copra tutte le
piattaforme target (Android, iOS, Flutter Web su Chrome/Firefox, Desktop
Windows/macOS/Linux) ed esponga un'interfaccia utilizzabile da un **agente AI**
(Claude / Copilot / Cursor) via MCP per validare in autonomia i ticket
implementati (integrazione A/Δ rispetto a `main`).

Direzione già decisa a monte (vedi report allegato):

- **Patrol** (LeanCode) come framework E2E primario, esteso su
  `integration_test` ufficiale.
- **Patrol MCP** come ponte verso l'agente AI, in locale.
- **`integration_test` "puro"** come fallback per il Desktop finché Patrol non
  ha un runner nativo maturo su Windows/Linux.
- Playwright MCP e Maestro considerati e **scartati come primari** — restano
  come opzioni tattiche per casi specifici (browser non-Chromium, flow YAML
  mobile no-code).

## Report

Ricerca completa e matrice di copertura:
[assets/17-e2e-testing-flutter-report.md](assets/17-e2e-testing-flutter-report.md)

## Vincolo operativo (solo-dev)

- **Unico sviluppatore su macOS**. Piattaforme fisicamente accessibili in
  esecuzione locale: **macOS host, simulatore iOS, emulatore Android, browser
  (Chrome/Safari/Firefox su macOS)**. Windows e Linux esistono come target di
  build ma **non c'è un ambiente in cui eseguire i test E2E in tempo reale su
  quelle piattaforme**, né budget per una pipeline CI multi-host (macOS +
  Windows + Linux runner).
- Corollario: Windows Desktop e Linux Desktop restano target di **build/smoke
  manuale occasionale**, non di test E2E automatizzati continui. Le scelte di
  strumenti e perimetro devono essere ottimizzate per il set eseguibile su
  macOS + mobile emulators + browser.

## Vincoli decisi a monte

- **Post-MVP**: non blocca la delivery dell'MVP di prodotto, ma abilita la
  pipeline "ticket → test automatico" che l'agente eseguirà sulla codebase
  Flutter una volta che l'MVP entra in implementazione.
- **Solo locale** (allineato al vincolo "no backend"): niente device farm come
  dipendenza, opzionale come acceleratore.
- **Licenze permissive**, coerente col vincolo licenze del progetto: Patrol e
  `integration_test` sono open source permissivi (BSD/MIT/Apache).
- **Compatibilità con lo stack del ticket 06**: qualunque scelta di test deve
  convivere con `flutter_bloc`, `go_router`, `pdf`+`printing`, `file_picker`,
  `super_editor`, `idb_shim`.

## Aree da grigliare

Prima di aprire l'implementazione, restano da chiudere:

1. **Perimetro di copertura per piattaforma**: quali flow sono E2E obbligatori
   su tutte (create-variant, edit, export PDF, import PDF, rename/duplica),
   quali solo su un sottoinsieme (es. share sheet solo mobile, download file
   solo web).
2. **Desktop native dialogs** (file picker OS, save dialog): fino a che punto
   testarli davvero e con quale ripiego (script OS-level:
   PowerShell/AppleScript/xdotool) dato che Patrol non copre i dialoghi
   nativi desktop.
3. **Flutter Web renderer**: CanvasKit vs HTML — se resta CanvasKit va valutato
   quanto Patrol Web/Playwright possano davvero interagire con la UI o se
   serve abilitare esplicitamente `Semantics` per l'accessibility tree.
4. **Firefox / WebKit**: se il requisito "principali browser incluso Firefox"
   è vincolante, decidere se Patrol Web (Chromium-first via Playwright) basta
   o serve affiancare Playwright MCP standalone.
5. **Contratto MCP per l'agente**: quali tool esporre (list_tests, run_test,
   inspect_ui, screenshot, generate_test), come mappare il "ticket" (issue
   Markdown) ai criteri di accettazione machine-readable, come gestire il
   loop di self-healing sui selettori.
6. **Ambienti CI/lokal**: dove girano davvero i test (macOS host per iOS,
   Windows host per Windows Desktop, Linux con Xvfb per Linux Desktop) — o se
   accettiamo copertura a scacchiera per piattaforma.
7. **Convivenza con `super_editor`**: l'editor WYSIWYG (ticket 06/07) è
   notoriamente complesso da testare via selettori — decidere strategia
   (test key semantiche esplicite? screenshot diff? evitare del tutto E2E
   sui campi rich text?).

## Impatti attesi su altri ticket

- **Ticket 06 (stack Flutter)**: aggiungere `patrol`, `patrol_cli`,
  `patrol_mcp` come `dev_dependencies` una volta chiusa la scelta.
- **Ticket 07 (UX editor)** e **08 (template PDF)**: definire `Key`
  stabili/semantiche sui widget critici per rendere i test resistenti al
  refactoring.
- **Mappa Wayfinder**: nuova sezione "Testing & agentic workflow" — questo è
  il primo ticket di quell'area, potenzialmente ne seguiranno altri
  (CI setup, contratto MCP formale, playbook agente).

## Risoluzione

Decisioni prese in questa sessione (aree 1, 2, 3+4, 6, 7 del blocco "Aree
da grigliare"). L'**area 5 — contratto MCP per l'agente** è **fuori scope
MVP** e rimandata alla v2: dettagli emersi in coda a questo blocco come
input per la sessione futura.

### Vincolo strutturale (già in cima al ticket)

Solo-dev su macOS. Piattaforme fisicamente eseguibili in E2E automatizzato:
**iOS Simulator, Android Emulator, browser (Chrome) su macOS, macOS
Desktop**. Windows Desktop e Linux Desktop **fuori dal perimetro E2E
automatizzato**: coperti da build + smoke manuale occasionale al bump di
versione. Nessuna pipeline CI multi-host (no budget, no motivazione
oggi).

### 1. Perimetro di copertura per piattaforma

**Piattaforme in E2E automatizzato locale**: iOS Simulator, Android Emulator,
Chrome (Web), macOS Desktop.

**Flow E2E obbligatori sul set eseguibile** (iOS + Android + Web Chrome +
macOS):
- create-variant (da zero)
- edit strutturato (aggiunta di un'Esperienza, save, riapertura, dato
  presente)
- rename / duplica / elimina variante
- export PDF (verifica che il file esca, size > 0, magic bytes `%PDF-`;
  no diff visuale del rendering)
- auto-save (edit → attesa 800ms → riapri → dato presente)

**Flow E2E a copertura ridotta**:
- **import PDF** → E2E su macOS + iOS + Android in ogni caso. Su **Web**
  segue il principio "test = verità di produzione" (vedi §3): se
  `pdfrx` su Web WASM funziona (Esito A del ticket 10) l'import è testato
  E2E su Chrome con le stesse fixture; se `pdfrx` è rotto su Web (Esito
  B) e in produzione l'import è disabilitato, l'E2E su Web verifica solo
  che il pulsante sia disabilitato + messaggio esplicito. Nessun test
  fantasma su feature non esposte.
- **share/save del `.cvapp`** → mobile: apertura share sheet (Patrol
  native automation); macOS: apertura save dialog (dopo di che il picker
  reale è sostituito, vedi §2); Web: verifica che parta il download.

**Non-goal E2E** (rinunciato o coperto altrove):
- diff visuale del PDF esportato → smoke manuale, non E2E
- euristiche mapping PDF→schema del ticket 13 → test unitari dedicati
- rendering fine di `super_editor` → widget test, non E2E (vedi §5)
- Windows/Linux Desktop → build+smoke manuale, non E2E

**Fixture** in `test/e2e/fixtures/`, versionate: 2–3 PDF di riferimento
(uno lineare "buono", uno con layout creativo, uno scansionato per
verificare la UX degradata del ticket 12) + 2 `.cvapp` di esempio.

### 2. Desktop native dialogs (macOS)

Patrol non copre i dialoghi Cocoa desktop. Strategia: **fake picker via
dependency injection dietro flag di test**.

- Il codice di produzione incapsula `file_picker` dietro un contratto
  `abstract class FileSystemService`.
- In build E2E (`--dart-define=E2E=true`) il fake restituisce percorsi
  fixture per `pickFiles` e scrive in una tmpdir controllata per
  `saveFile`.
- L'E2E verifica: click → app chiama il servizio → app decodifica/salva
  correttamente → stato UI aggiornato. **Non** verifica che il dialog
  Cocoa reale si apra: responsabilità del pacchetto `file_picker`,
  coperta da smoke manuale al bump di versione.

Rinunciato: AppleScript/`osascript` per pilotare dialoghi Cocoa reali
(fragile su localizzazione, sync UI difficile, manutenzione alta).

### 3. Web renderer e 4. Cross-browser

**Renderer**: default corrente di Flutter Web (CanvasKit/Skwasm), nessun
`--web-renderer html` (deprecato). Il canvas è opaco a Playwright: nelle
build di test si attiva `SemanticsBinding.instance.ensureSemantics()`
dietro `--dart-define=E2E=true` per esporre l'accessibility tree.
Widget target dei test hanno `Semantics(label: '<stable-key>', ...)` +
`Key('<stable-key>')` — l'elenco degli identificatori stabili è un
appendix del ticket 07.

**Cross-browser**: **solo Chrome in E2E automatizzato**. Firefox e Safari
coperti da smoke manuale al bump di versione (~10 min di click sui
flow principali). Motivazione: Patrol Web è Chromium-first via
Playwright; triplicare il runtime della suite Web su un budget locale
di solo-dev non regge; il grosso del rendering Flutter Web vive nel
canvas — bug browser-specifici sopra quello strato sono rari e catturabili
con smoke manuale.

### 6. Ambienti di esecuzione

**100% locale, on-demand, da CLI. Nessuna CI.**

- Un target Makefile per piattaforma: `make e2e-ios`, `make e2e-android`,
  `make e2e-web`, `make e2e-macos`, + `make e2e-all`.
- Prerequisiti d'ambiente (documentati nel README della suite E2E) a
  carico dello sviluppatore prima di lanciare i test:
  - iOS Simulator già avviato (o boot via `xcrun simctl` nel target)
  - Android Emulator già avviato (o boot via `emulator -avd`)
  - Chrome installato (Playwright/Patrol Web porta il chromedriver)
- Fixture in `test/e2e/fixtures/`, versionate.
- Cadenza suggerita: `make e2e-ios` (il più veloce, ~5 min) prima di
  commit non triviali; `make e2e-all` (~20 min) prima di push su `main`.

Nessuna CI su GitHub Actions **oggi**. Rivalutabile solo quando il
progetto uscirà dal solo-dev o quando la suite sarà stabile abbastanza
da giustificare il costo di setup.

### 7. Convivenza con `super_editor`

Strategia ibrida:

- **Backdoor di test `TestHooks.setEditorContent(fieldKey, markdown)`**
  dietro `--dart-define=E2E=true`. Scrive direttamente nel
  `DocumentComposer` bypassando tastiera+toolbar. Usata dai flow E2E
  principali per popolare rapidamente i campi rich text con Markdown
  fissato dalle fixture.
- **Un solo E2E "Editor felice"** che fa il flow reale (tap sul campo
  Sommario → `enterText("ciao mondo")` → salva → riapri → verifica che il
  Markdown salvato contenga la stringa). Cattura regressioni grosse di
  `super_editor` senza pretendere di testare toolbar e selezione.
- **Formattazione fine** (bold/italic/liste, click toolbar, undo/redo) →
  **widget test dedicati** sul wrapper `super_editor` + `super_editor_markdown`,
  **non E2E**.

**Non-goal**: diff pixel del Markdown renderizzato, testing di
cursore/selezione via input reale. Se `super_editor` risulterà
ingestibile in fase implementativa, il fallback documentato nel ticket
06 (TextField + toolbar custom) semplifica anche il testing E2E — la
strategia sopra resta valida.

### Amendment ticket 06 (stack Flutter)

Aggiungere come `dev_dependencies` una volta chiusa
l'implementazione: `patrol`, `patrol_cli` (BSD-3-Clause).
`integration_test` è già incluso nell'SDK Flutter. `patrol_mcp`
esplicitamente escluso dall'MVP (vedi §5 sotto).

### Amendment ticket 07 (UX editor)

- Nuovo appendix: **elenco delle `Key` semantiche stabili** dei widget
  critici che l'E2E deve poter selezionare (pulsanti di libreria,
  campi obbligatori del form, pulsanti di export/import, indice della
  sidebar, ecc.). L'elenco è la fonte di verità dei selettori E2E.
- Nota architetturale: i campi rich text espongono un identificatore
  per `TestHooks.setEditorContent`.

### Amendment ticket 04 (storage) / ticket 06 (stack)

Nuovo contratto `abstract class FileSystemService` che incapsula
`file_picker`: implementazione reale in produzione, fake in build E2E.

---

### 5. Contratto MCP per l'agente — fuori scope MVP, → v2

**Deferred.** L'automazione "ticket implementato → test E2E scritto e
verificato dall'agente" è un'evoluzione di fase 2 e non pesa nella
scelta di stack e perimetro dell'MVP. Nell'MVP i test E2E si scrivono a
mano quando servono, seguendo la struttura Patrol standard.

Materiale emerso da riprendere in v2 quando si affronterà (input alla
prossima sessione, non decisioni prese):

- **Server MCP candidato**: `patrol_mcp` (LeanCode, Dart, dev-dependency,
  già valutato nel report), che espone nativamente `list_tests`,
  `run_test`, output di fallimento.
- **Contratto ticket → test machine-readable**: convenzione da definire
  (YAML strutturato vs prosa Markdown vs ibrido) per una sezione
  `## Accettazione E2E` nei ticket implementativi, con almeno `id`,
  `platforms`, `scenario`, `keys`, `hooks`. Serve deterministica per
  parsing agente.
- **Skill di progetto `/implement-cv`** che estende `/implement`
  aggiungendo fasi: (B) genera il file di test da `## Accettazione E2E`
  usando `list_keys` + `list_test_hooks`; (C) `run_test` su tutte le
  `platforms`; (D) loop di riparazione con N iterazioni max e diff-per-review
  al fallimento; (E) commit solo se tutti verdi.
- **Tool MCP custom** da valutare: `list_keys` (legge un
  `test/e2e/keys.dart` autogenerato dagli identificatori stabili del
  ticket 07/08), `list_test_hooks` (elenca i `TestHooks` esposti
  dall'app). Servono per impedire all'agente di inventare selettori.
- **Prerequisiti d'ambiente**: `.mcp.json` nel repo, iOS Sim / Android
  Emu / Chrome avviati prima della sessione (script `make e2e-env-up`
  o boot dentro la skill stessa).
- **Non-goal in v2**: `inspect_ui` live su emulatore vivo,
  `generate_test` end-to-end da linguaggio naturale senza ticket,
  screenshot diff visuale, self-healing probabilistico dei selettori.
- **Motivi per rimandare**: (a) senza un corpus di ticket
  implementativi già chiusi non si può tarare il formato del contratto
  di accettazione; (b) il valore dell'automazione si vede solo quando
  la suite E2E ha abbastanza test da rendere costoso scriverli a mano;
  (c) introdurre il flusso ora rischia di creare più problemi che
  benefici (parole dell'utente).
