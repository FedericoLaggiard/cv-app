# cv_app — Flutter app

[![CI](https://github.com/FedericoLaggiard/cv-app/actions/workflows/ci.yml/badge.svg)](https://github.com/FedericoLaggiard/cv-app/actions/workflows/ci.yml)
[![mutation-test](https://github.com/FedericoLaggiard/cv-app/actions/workflows/mutation-nightly.yml/badge.svg)](https://github.com/FedericoLaggiard/cv-app/actions/workflows/mutation-nightly.yml)
[![coverage](https://codecov.io/gh/FedericoLaggiard/cv-app/branch/main/graph/badge.svg)](https://codecov.io/gh/FedericoLaggiard/cv-app)

Implementazione dell'MVP descritto in [`docs/cv-app/map.md`](../docs/cv-app/map.md).

## Cosa c'è oggi

Questa iterazione copre i tickets 01→04, 07 e 14:

- **Schema dati tipizzato** (`lib/src/domain/`)
  - `SectionKind`, enum CEFR / modalità / contratto / genere / stato civile
    (wire snake_case ASCII, identificatori Dart lowerCamelCase).
  - `YearMonth` value object (`YYYY-MM`, immutabile, comparabile).
  - Sezioni sealed su `CvSection`: `Anagrafica`, `Contatti`, `Sommario`,
    `Esperienze`, `Formazione`, `Skill`, `Lingue`, `Certificazioni`, `Custom`.
  - `CvDocument` con `schemaVersion`, `id`, timestamp UTC, `variantName`,
    `sections[]` ordinate, `assets{}` base64.
- **Codec JSON strict** (`json_codec.dart`)
  - Round-trip minified UTF-8 conforme al ticket 03.
  - Unknown fields → `CvSchemaException` a ogni livello.
  - `schemaVersion > CURRENT` → `CvSchemaTooNewException` (refuse-if-newer).
  - Migrations forward-only in `migrations.dart` (v1 = no-op oggi; agganciare
    `_migrate_N_to_Np1` al bump).
- **Invarianti** (`validation.dart`) — divise in due famiglie, perché
  rispondono a due domande diverse:
  - `validateStructure()` — **coerenza**, applicata da `save()`, dal
    caricamento e dall'import: unicità `displayTitle` (case-insensitive +
    trim), unicità `kind` per sezioni non-custom, item id presenti e
    univoci, `current` xor `endDate`, range date coerenti, riferimenti
    asset risolvibili. Un documento che le viola è corrotto e non finisce
    mai su disco.
  - `completenessIssues()` — **completezza** (nome/cognome, ruolo+azienda,
    titolo, lingua, nome+ente): non blocca nulla. Una bozza li viola per
    definizione mentre l'utente digita (ticket 07, "nessun blocco durante
    l'editing"); sono ciò che l'export segnala prima di produrre il PDF.
    Derivati da `analyzeMissingRequired()` (`missing_required.dart`), la
    stessa fonte che accende i badge ⚠ nell'editor.
  - `validate()` — entrambe insieme, per i punti in cui pretendiamo un CV
    finito.
- **Asset GC** al save (`garbageCollectAssets`).
- **`CvRepository`** astratto + `InMemoryCvRepository` (`lib/src/repository/`).
  - Stream reattivi per Libreria/Editor, `Future` per azioni.
  - Naming duplicati coerente col ticket 14 (`<name> (N)`).
  - `ImportResult` sealed: Success/Conflict/Corrupt.
- **Backend concreti** del repository: `path_provider` (desktop/mobile) e
  `idb_shim` (web), scelti da `defaultCvRepository()` — ticket 04.
- **Schermata Libreria** (`lib/src/ui/library/`) — card variante, menu
  Duplica/Rinomina/Esporta/Elimina, stato vuoto con CTA — ticket 14.
- **Editor strutturato** (`lib/src/ui/editor/`) — ticket 07:
  - `EditorBloc`: `watch(id)` in lettura, auto-save con debounce 800 ms,
    stato di collapse per sezione tenuto in memoria (non serializzato).
  - Layout a due colonne ≥ 900 px (sidebar-indice + scroll unico), colonna
    singola con indice a bottom sheet sotto.
  - Form tipizzati per Anagrafica, Contatti, Esperienze, Formazione, Skill,
    Lingue, Certificazioni; riordino sezioni via drag handle + menu `[⋯]`;
    dialog `Aggiungi sezione` (fisse mancanti + custom).
  - Badge ⚠ soft su indice, header sezione e voce; nessun blocco
    all'editing, nessun salvataggio perso.
- **CI locale al commit** (`Makefile`, `.husky/`) — ticket 18:
  - `pre-commit` esegue `make ci-fast` (registry + analyze + test +
    complessità); `pre-push` è vuoto.
  - `flutter analyze --fatal-infos --fatal-warnings`, tolleranza zero.
  - Complessità ciclomatica via `dart_code_linter`: CC 10 / nesting 5 su
    `lib/src/domain/` e `lib/src/repository/`, CC 20 / nesting 5 su
    `lib/src/ui/` e `lib/src/app/`; nessuna esclusione oltre ai generati.
  - `check-registry` blocca un `pubspec.lock` che punta a un registry
    diverso da pub.dev.
  - Bypass: `git commit --no-verify`.

## Cosa **non** c'è ancora

Per iterazione futura, in ordine dei ticket:

- Import PDF (`pdfrx` + euristiche) — ticket 05, 10, 12, 13.
- Editing rich text con `super_editor` — oggi Sommario, Sezioni custom e la
  descrizione di Skill mostrano un placeholder; le descrizioni di
  Esperienze/Formazione sono `TextField` multilinea in attesa del Markdown.
- Foto profilo nell'editor (`AnagraficaData.foto`) — ticket 09.
- Route anteprima PDF a piena pagina + dialog "campi mancanti / Esporta
  comunque" che consuma `completenessIssues()` — ticket 08.
- Template PDF Classico/Moderno/Minimal (`pdf` + `printing`) — ticket 08.
- i18n IT/EN (ARB) + Impostazioni — ticket 15.
- Onboarding overlay — ticket 16.
- E2E Patrol locale — ticket 17.

Migrazione a `freezed` v3 + `json_serializable` (decisa in ticket 06) è
rimandata: i data class sono scritti a mano finché la forma non è
stabilizzata dai ticket UI.

## Comandi

```bash
cd src
flutter pub get
make setup-hooks   # installa gli hook git (una volta, dopo il clone)
make ci-fast       # registry + analyze + test + complessità (girato anche al commit)
```
