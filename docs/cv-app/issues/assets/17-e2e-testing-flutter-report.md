# Tool E2E per Flutter (web, desktop, mobile) guidabile da un agente AI

**Data:** 2026-08-24
**Contesto richiesta:** trovare un tool di test end-to-end che simuli un utente
reale che clicca sui pulsanti di un'app Flutter, con queste caratteristiche:

- Esecuzione **locale**.
- Copertura di **Flutter Web** (Firefox, Chrome, …), **Flutter Desktop**
  (Windows, macOS, Linux) e **Flutter Mobile** (Android, iOS).
- Facilmente **pilotabile da un agente AI** (Claude, Copilot, Cursor, …), o via
  **MCP server** o tramite CLI richiamabile dall'agente, per validare in
  autonomia integrazioni "A/Δ" rispetto ai ticket sviluppati.

Nessun singolo tool copre *perfettamente* tutti i requisiti oggi (agosto 2025).
La risposta pratica è una **combinazione di 2 tool**, con **Patrol** come
elemento centrale.

---

## 1. Riepilogo esecutivo / raccomandazione

| Requisito | Raccomandazione |
|---|---|
| Un solo tool per tutto | **Patrol** (LeanCode) — copre Android, iOS, Web e ha copertura crescente su Desktop tramite `integration_test`. |
| Piano B se serve solo mobile "senza codice" | **Maestro** (mobile.dev) — YAML + MCP server ufficiale. |
| Solo Flutter Web con agente AI | **Playwright MCP** (Microsoft) come server MCP standard per Claude. |
| Base ufficiale su cui tutti si appoggiano | `integration_test` di Flutter — supportato ufficialmente su mobile, web e desktop. |
| Integrazione con Claude / Copilot / Cursor via MCP | **Patrol MCP** (`patrol_mcp` di LeanCode) + **Maestro MCP** + **Playwright MCP**. |

**Stack consigliato (locale + agent-driven):**

1. **Patrol** per scrivere/eseguire i test E2E (Android, iOS, Web).
2. **`integration_test`** direttamente per Desktop (Windows, macOS, Linux) —
   Patrol non ha ancora un runner nativo desktop maturo.
3. **Patrol MCP** come server MCP verso Claude/Copilot: l'agente esegue i test,
   ispeziona l'albero widget, fa screenshot, genera nuovi test in linguaggio
   naturale a partire dal ticket.
4. Opzionale: **Playwright MCP** per test browser puri (Firefox/WebKit) o UI
   web non completamente accessibile via l'albero semantico di Flutter.

---

## 2. Il perché: mappa dei tool disponibili

### 2.1 `integration_test` (ufficiale Flutter)

- Pacchetto ufficiale del team Flutter, sostituisce il deprecato
  `flutter_driver` ([docs.flutter.dev/testing/integration-tests](https://docs.flutter.dev/testing/integration-tests)).
- Copertura piattaforme: **Android, iOS, Web, Windows, macOS, Linux**
  (`flutter test integration_test` o `flutter drive`).
- Sintassi vicina ai widget test (`WidgetTester`), quindi test scritti in Dart.
- Limite: **non interagisce** con dialoghi/permessi nativi del sistema
  operativo, notifiche di sistema, webview, browser esterni.
- Ideale come base tecnica; molti altri tool (Patrol) lo estendono anziché
  sostituirlo.

### 2.2 Patrol (LeanCode) — la scelta più vicina al "tool unico"

- Repo: <https://github.com/leancodepl/patrol>; docs: <https://patrol.leancode.co/>.
- Framework Flutter-first che **estende `integration_test`** aggiungendo:
  - accesso a UI native (permessi, notifiche, settings, WebView, dark mode,
    clipboard, cookies) tramite ponti nativi (UIAutomator per Android,
    XCUITest per iOS, Playwright per il Web);
  - finder più leggibili (`$(#login).tap()`), custom finders;
  - CLI `patrol test` con selezione device, `--web-headless`, integrazione con
    Firebase Test Lab / BrowserStack / SauceLabs / AWS Device Farm.
- Copertura piattaforme (stato al 2025):
  - **Android**: maturo, produzione.
  - **iOS**: maturo, produzione.
  - **Flutter Web**: supporto ufficiale da Patrol 4.0 (2024) usando
    **Playwright** come motore browser
    ([Patrol Web docs](https://patrol.leancode.co/documentation/web),
    annuncio 4.0: <https://leancode.co/blog/patrol-4-0-release>).
    In pratica: `patrol test --device chrome`; Playwright espone Chromium,
    Firefox e WebKit, quindi *Chrome/Chromium e Firefox sono coperti*; Safari
    via WebKit. Attenzione: la documentazione più visibile parla di
    Chromium; verificare per Firefox nella versione specifica in uso.
  - **Desktop (Windows / Linux)**: **non c'è ancora un runner nativo Patrol**
    con accesso ai dialoghi di sistema; sul desktop si ricade su
    `integration_test` "puro" (che Patrol comunque abbraccia).
  - **macOS**: in evoluzione, con Swift Package Manager support recente
    (`patrol_cli` su [pub.dev](https://pub.dev/packages/patrol_cli)).
- **Patrol MCP** (`patrol_mcp`, LeanCode 2025) — punto chiave per il caso
  d'uso "agente autonomo che testa i ticket":
  - server MCP in Dart che espone all'agente le operazioni: lista test, run
    singolo test, cattura screenshot per piattaforma, lettura dell'albero UI
    nativo, generazione di nuovi test Patrol da istruzioni in linguaggio
    naturale ([annuncio LeanCode](https://leancode.co/blog/patrol-mcp-release),
    <https://patrol.leancode.co/patrol-mcp-announcement>);
  - compatibile con Claude Desktop, Claude Code, Cursor, Copilot e qualunque
    client MCP;
  - configurazione tipica: aggiungere `patrol_mcp` come dev dependency,
    esportare `FLUTTER_PROJECT_PATH`, registrare il server nel file di
    configurazione MCP dell'agente.

Perché è la scelta principale per la richiesta: è **l'unico framework
Flutter-first** che (a) copre mobile+web con un'unica sintassi, (b) è pensato
per essere agentic-first grazie a un MCP server ufficiale.

### 2.3 Maestro (mobile.dev) — alternativa "no-code" mobile

- Docs: <https://docs.maestro.dev/>; MCP server ufficiale:
  <https://docs.maestro.dev/get-started/maestro-mcp>.
- Flow in YAML, molto leggibili; l'agente può generarli senza toccare Dart.
- Supporto: **Android, iOS**; supporto **Flutter Web** limitato e
  **Desktop assente**. Quindi non è "tool unico" per la tua matrice, ma è
  eccellente lato mobile ed espone un MCP server maturo che Claude sa già
  guidare (vedi anche il progetto community
  [Code-Growers/flutter_maestro_mcp](https://github.com/Code-Growers/flutter_maestro_mcp)
  che collega Maestro al VM Service di Flutter per ispezionare l'albero
  widget).
- Utile come **secondo layer** solo se serve un ciclo di scrittura test
  ultra-veloce da parte dell'agente sui mobile.

### 2.4 Playwright + Playwright MCP — per Flutter Web multi-browser

- Playwright supporta **Chromium, Firefox, WebKit** in locale, headed o
  headless. È il motore che Patrol Web usa internamente.
- **Playwright MCP** (Microsoft) è il server MCP di riferimento per far
  guidare un browser reale a Claude/Copilot
  ([playwright.dev/docs/getting-started-mcp](https://playwright.dev/docs/getting-started-mcp),
  repo `@playwright/mcp`). Espone la pagina come *accessibility tree*, quindi
  l'agente non ha bisogno di vision model.
- Limite per Flutter Web: Flutter renderizza spesso tramite CanvasKit
  (WebGL/Canvas), quindi buona parte della UI non è nell'albero HTML/ARIA.
  Per usarlo davvero servono:
  - build web con renderer HTML *o* `Semantics` esplicite / `--web-renderer html`
    (deprecato in versioni recenti) *o* attivazione del semantic tree via
    `SemanticsBinding` per fornire ruoli accessibili;
  - selezione degli elementi via testo/ruolo, non via chiavi Flutter.
- **Quando ha senso**: se vuoi test browser "puri" su Firefox oltre a Chrome,
  o se il tuo target primario è la web app e vuoi che l'agente Claude la
  piloti come un utente vero. In un progetto Flutter-first, però, **Patrol
  Web è più ergonomico** perché parla con i widget, non con l'HTML.

### 2.5 Appium (+ Appium MCP)

- Alternativa storica mobile, cross-SDK. Esistono `appium-mcp` community
  (`Rahulec08/appium-mcp`, `sparky77/appium-mcp-server`) che espongono
  comandi Appium al modello.
- Su Flutter richiede setup extra (semantics/accessibility IDs). Non è
  ottimale per il caso "Flutter puro"; utile solo se il team ha già
  infrastruttura Appium condivisa con app non-Flutter.

### 2.6 Note su alternative AI-native (`flutter-skill`, `testwire_mcp`, `mcp_flutter`)

- [`ai-dashboad/flutter-skill`](https://github.com/ai-dashboad/flutter-skill),
  [`Arenukvern/mcp_flutter`](https://github.com/Arenukvern/mcp_flutter),
  [`testwire_mcp`](https://pub.dev/packages/testwire_mcp) sono progetti
  community "AI-first" che espongono via MCP l'app Flutter in esecuzione
  (VM Service, hot reload, ispezione widget) all'agente.
- Interessanti come *complemento* per lasciare l'agente esplorare l'app,
  ma nessuno oggi è alla stessa maturità di Patrol per test E2E su tutte le
  piattaforme richieste. Da valutare come acceleratore in fase esplorativa,
  non come runner CI/CD primario.

---

## 3. Matrice di copertura vs. requisiti

Legenda: ✅ pieno · 🟡 parziale/workaround · ❌ non supportato.

| Requisito | Patrol | integration_test | Maestro | Playwright MCP | Appium |
|---|---|---|---|---|---|
| Esecuzione locale | ✅ | ✅ | ✅ | ✅ | ✅ |
| Android | ✅ | ✅ | ✅ | ❌ | ✅ |
| iOS | ✅ | ✅ | ✅ | ❌ | ✅ |
| Web – Chrome/Chromium | ✅ | ✅ | 🟡 | ✅ | ❌ |
| Web – Firefox | ✅ (via Playwright) | 🟡 (via `flutter drive -d web-server`) | ❌ | ✅ | ❌ |
| Web – WebKit/Safari | 🟡 | 🟡 | ❌ | ✅ | ❌ |
| Desktop Windows | 🟡 (senza dialoghi nativi) | ✅ | ❌ | ❌ | 🟡 |
| Desktop macOS | 🟡 | ✅ | ❌ | ❌ | 🟡 |
| Desktop Linux | 🟡 | ✅ | ❌ | ❌ | ❌ |
| Interazioni native (permessi, notifiche, WebView) | ✅ | ❌ | ✅ (mobile) | ✅ (browser) | 🟡 |
| MCP server ufficiale per Claude/Copilot | ✅ (`patrol_mcp`) | ❌ | ✅ | ✅ | 🟡 (community) |
| Test in linguaggio naturale generati dall'agente | ✅ | ❌ | ✅ | ✅ | 🟡 |
| Ready per CI/CD locale + device farm | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 4. Architettura consigliata per "agente che testa i ticket in autonomia"

1. **Repository dell'app Flutter** con:
   - `integration_test/` per i test cross-platform baseline.
   - `patrol/` (o `integration_test/` esteso con Patrol) per gli E2E ricchi.
   - `dev_dependencies: patrol`, `patrol_cli`, `patrol_mcp`.

2. **Server MCP attivi in locale**:
   - `patrol_mcp` — driver principale per mobile/web di Flutter.
   - `@playwright/mcp` — solo se vuoi far pilotare all'agente Firefox/WebKit
     lato browser puro.
   - opzionale `maestro mcp` — se il team preferisce YAML lato mobile.

3. **Configurazione lato agente (Claude Code / Claude Desktop / Copilot /
   Cursor)** — esempio di `mcp.json`:
   ```json
   {
     "servers": {
       "patrol":     { "command": "dart", "args": ["run", "patrol_mcp"] },
       "playwright": { "command": "npx",  "args": ["@playwright/mcp@latest"] }
     }
   }
   ```

4. **Workflow "ticket → test"** che l'agente esegue in autonomia:
   1. Legge il ticket (issue/PR) e i file modificati (Δ rispetto a `main`).
   2. Interroga `patrol_mcp` per l'elenco dei test esistenti e per l'albero
      widget della schermata toccata.
   3. Genera un nuovo test Patrol Dart (o un flow YAML Maestro) coerente con
      gli acceptance criteria del ticket.
   4. Esegue il test su ogni target richiesto: `patrol test -d android`,
      `-d ios`, `-d chrome`; per Desktop invoca `flutter test integration_test
      -d windows|macos|linux`.
   5. Raccoglie screenshot, log, e in caso di failure ripete inspection +
      self-healing sul selettore.
   6. Riporta esito nel PR / issue.

5. **Considerazioni operative**:
   - Per il web multi-browser locale, considera un container/VM per Firefox
     e WebKit se serve reproducibilità in CI.
   - Per iOS servono comunque macOS + Xcode; per Windows Desktop servono
     Visual Studio Build Tools; per Linux Desktop `flutter test` in un runner
     con Xvfb (o display reale) per emulare l'ambiente grafico.
   - Firma binari e permessi di automazione (specialmente su macOS) vanno
     concessi al processo che esegue Patrol / Playwright.

---

## 5. Rischi e incognite

- **Desktop + native dialogs**: nessun tool ha oggi parità con mobile per
  interagire con dialoghi *nativi del sistema* su Windows/Linux
  (`integration_test` copre solo il layer Flutter). Se il ticket richiede di
  cliccare un file picker nativo o un permesso OS, sarà necessario aggiungere
  script OS-level (PowerShell/AppleScript/xdotool) accanto al test Patrol.
- **Flutter Web con CanvasKit**: la UI non è nel DOM standard. Patrol Web
  gestisce meglio perché parla via `integration_test`, ma Playwright MCP
  standalone fatica se non abiliti le semantics o non ti basi sul testo
  visibile.
- **Stabilità Patrol MCP**: rilasciato nel 2025, ecosistema giovane. Le API
  MCP potrebbero cambiare; verificare la versione contro quella di
  `patrol_cli` in uso.
- **Costo di manutenzione**: adottare più server MCP (Patrol + Playwright +
  Maestro) moltiplica configurazione e superficie di errore; consiglio di
  partire con **solo Patrol MCP** e aggiungere gli altri se emergono gap.

---

## 6. Percorso di adozione suggerito (2 settimane)

1. **Settimana 1** — introdurre `integration_test` + Patrol nel repo, portare
   1 flow critico per piattaforma (mobile, web, desktop). Validare che
   `patrol test` gira in locale su Chrome, Android emulator, iOS simulator,
   e che `flutter test integration_test -d {windows|macos|linux}` gira sui
   rispettivi host.
2. **Settimana 2** — installare `patrol_mcp` e collegarlo a Claude Code /
   Copilot. Definire il "playbook ticket → test" (sezione 4). Aggiungere in
   coda Playwright MCP se serve Firefox/WebKit puro. Solo dopo valutare
   Maestro se il team vuole flow YAML.

---

## 7. Riferimenti principali

- Patrol (framework, docs): <https://patrol.leancode.co/>,
  <https://github.com/leancodepl/patrol>
- Patrol Web: <https://patrol.leancode.co/documentation/web>,
  annuncio 4.0: <https://leancode.co/blog/patrol-4-0-release>
- Patrol MCP: <https://leancode.co/blog/patrol-mcp-release>,
  <https://patrol.leancode.co/patrol-mcp-announcement>
- `patrol_cli` su pub.dev: <https://pub.dev/packages/patrol_cli>
- Flutter `integration_test`: <https://docs.flutter.dev/testing/integration-tests>,
  README ufficiale:
  <https://github.com/flutter/flutter/blob/master/packages/integration_test/README.md>
- Maestro MCP: <https://docs.maestro.dev/get-started/maestro-mcp>,
  post introduttivo: <https://maestro.dev/blog/maestro-mcp-an-introduction>
- Flutter Maestro MCP (community):
  <https://github.com/Code-Growers/flutter_maestro_mcp>
- Playwright MCP: <https://playwright.dev/docs/getting-started-mcp>,
  pacchetto: <https://www.npmjs.com/package/@playwright/mcp>
- Dart/Flutter MCP server ufficiale:
  <https://docs.flutter.dev/ai/mcp-server>
- Progetti AI-first per Flutter:
  <https://github.com/Arenukvern/mcp_flutter>,
  <https://github.com/ai-dashboad/flutter-skill>,
  <https://pub.dev/packages/testwire_mcp>
- Confronto E2E Flutter 2025:
  <https://programtom.com/dev/2025/08/19/e2e-testing-options-flutter/>,
  <https://dev.to/3lvv0w/flutter-mobile-testing-methodologies-recap-2025-523j>
