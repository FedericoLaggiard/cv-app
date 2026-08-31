# Continuous integration locale (quality gate al commit)

Type: grill-with-docs
Status: open
Depends on: 19 (bonifica), 20 (refactoring validation), 21 (freezed cv_section)
Blocks: —

## Question

Definire una pipeline di **continuous integration eseguita interamente in
locale**, agganciata al flusso git, che impedisca di committare codice che non
rispetta gli standard del progetto.

Step richiesti dall'utente:

1. Esecuzione della suite di test Dart, con esito verde obbligatorio.
2. Esecuzione dell'analisi statica Dart, allineata agli standard del linguaggio.
3. Calcolo della **complessità ciclomatica**, con quality gate.
4. **Mutation testing** con quality gate → **spostato al ticket 22** (vedi
   "Fuori scope" più sotto).

## Decisione

### Split degli hook

- **`pre-commit`** → `make ci-fast` = analyze + test + complessità. Ordine di
  secondi/decine di secondi.
- **`pre-push`** → nessun hook. Il mutation testing, unico candidato per il
  push, è fuori scope (ticket 22).

Motivo: un giro completo di mutation testing sul solo `lib/src/domain/` genera
**719 mutanti** e richiede **~90 minuti** (misurato). Su `pre-push`
equivarrebbe a un divieto di push.

### Installazione degli hook

- Pacchetto **`husky`** come dev-dependency + `dart run husky install`.
- Hook in **`.husky/`** (convenzione del pacchetto), `core.hooksPath` gestito
  da husky.
- Gli hook sono **gusci di una riga** che invocano un target del Makefile:
  tutta la logica sta nel Makefile, nessuna logica dentro `.husky/`.

Alternativa scartata: `core.hooksPath` nudo su `tool/hooks/`. Scelto husky per
avere l'installazione agganciata al ciclo di vita del package Dart.

### Motore: Makefile

`Makefile` alla radice di `src/`. Target:

| target | cosa fa |
|---|---|
| `setup-hooks` | `dart run husky install` |
| `analyze` | `flutter analyze --fatal-infos --fatal-warnings` |
| `test` | `flutter test` |
| `complexity` | `dart run dart_code_linter:metrics analyze lib` |
| `check-registry` | fallisce se `pubspec.lock` contiene host diversi da `pub.dev` |
| `ci-fast` | `check-registry` + `analyze` + `test` + `complexity` |

Il Makefile nasce anche per ospitare i target `e2e-*` previsti dal ticket 17,
che non erano mai stati creati.

### Perimetro

**Sempre tutto, sempre.** Suite intera e analisi sull'intero progetto, nessun
filtro sui file staged. Filtrare produce falsi verdi (una modifica in `lib/`
rompe test di file non toccati) ed è ottimizzazione prematura con 16 file di
test.

### Analyze: tolleranza zero

`flutter analyze --fatal-infos --fatal-warnings`. Qualsiasi segnalazione,
inclusi gli `info`, blocca il commit. Precondizione: debito azzerato dal
ticket 19.

### Complessità ciclomatica

Tool: **`dart_code_linter`** (MIT, fork di DCM 5.7 mantenuto da Bancolombia),
dev-dependency, esecuzione interamente offline.

Alternative scartate:
- **DCM** (`dcm.dev`): licenza commerciale, free tier con attivazione online →
  incompatibile con la policy licenze del progetto e col vincolo "100% locale".
- Script custom sull'analyzer AST: reinventare la ruota.

Soglie:

| perimetro | cyclomatic-complexity | maximum-nesting-level |
|---|---|---|
| `lib/src/domain/`, `lib/src/repository/` | **10** | 5 |
| `lib/src/ui/` | **20** | 5 |

Motivo delle due soglie: un `build()` con `Column(children: [...if (x) ...])`
accumula rami senza vera complessità cognitiva; un parser con gli stessi rami
è debito reale. La soglia 10 è quella classica di McCabe; 20 è il default del
tool ed è la tolleranza concessa ai widget.

**Nessuna esclusione, nessuna deroga, nessun file in `metrics-exclude`.** Il
gate nasce verde perché i ticket 19/20/21 hanno già ripulito il codice, non
perché nasconde qualcosa. L'unica esclusione ammessa è quella implicita dei
file **generati** (`*.freezed.dart`, `*.g.dart`), che nessuno scrive a mano.

### Registry: pub.dev, non il mirror aziendale

Il `pubspec.lock` committato oggi contiene URL `artifactory.gbm.lan` perché la
macchina di sviluppo ha `PUB_HOSTED_URL` impostata a un mirror aziendale. Un
repo non può disattivare una variabile d'ambiente della macchina, quindi:

- il **Makefile esporta `PUB_HOSTED_URL=https://pub.dev`** su tutti i target,
  isolando il progetto dalla configurazione della macchina senza toccare il
  setup di lavoro dell'utente;
- il target **`check-registry`** fallisce se `pubspec.lock` contiene host
  diversi da `pub.dev` — rete di sicurezza contro il rientro silenzioso del
  mirror.

La rigenerazione del lock è a carico del ticket 19.

### Report

Output su terminale per il verdetto; file di dettaglio in **`build/ci/`**
(già gitignorato da Flutter). Non committati: sono rumore generato.

### Bypass

Nessuna cerimonia aggiuntiva. `git commit --no-verify` è l'escape hatch e
basta: aggiungere una seconda porta di servizio accanto a una che git offre
già è teatro.

## Fuori scope

- **Mutation testing** → ticket 22. Non eseguibile in locale con tempi
  ragionevoli (719 mutanti, ~90 min): va su una pipeline notturna remota.
- **CI remota per test/analyze/complessità**: questi girano in locale al
  commit, non serve duplicarli in cloud.
- **Verifica automatica della versione di Flutter**: scartata. Un gate che va
  rosso perché Google ha rilasciato una versione stamattina blocca il commit
  per un motivo che non riguarda il codice. La policy "sempre l'ultima stable"
  si applica quando si aggiorna (ticket 19), non a ogni commit.
- **`fvm`**: scartato.

## Criteri di accettazione

- [ ] `make setup-hooks` installa gli hook su un clone pulito.
- [ ] `git commit` con un test rosso viene **bloccato**.
- [ ] `git commit` con un `info` di analyze viene **bloccato**.
- [ ] `git commit` con una funzione a CC 11 in `lib/src/domain/` viene
      **bloccato**; la stessa funzione in `lib/src/ui/` passa.
- [ ] `git commit` con nesting 6 viene **bloccato**.
- [ ] `make check-registry` fallisce su un `pubspec.lock` con URL Artifactory.
- [ ] Su codice pulito, `make ci-fast` è **verde senza alcuna esclusione**.
- [ ] I report finiscono in `build/ci/` e non sono tracciati da git.

## Note di misurazione (agosto 2026)

Misure fatte su una copia del branch `21-editor-strutturato` con Flutter
3.47.2 / Dart 3.13:

- `flutter analyze --fatal-infos --fatal-warnings`: **13 segnalazioni**
  (1 `deprecated_member_use` in `editor_screen.dart:412`, 12 `invalid_override`
  in `test/ui/editor/editor_bloc_test.dart`).
- `flutter test`: **182 test, 2 falliti**.
- Complessità oltre soglia in `lib/`: `_structuralErrors` 33,
  `analyzeMissingRequired` 16, `YearMonthField.build` 19,
  `AnagraficaForm.build` 12, `_FormazioneItemForm.build` 11,
  `AnagraficaData.copyWith`/`==` e `EsperienzaItem.copyWith`/`==` 11 ciascuna.
- Nesting: nessuna violazione oltre 5.
- `lib/src/repository/`: pulito.
