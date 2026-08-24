# cv_app — Flutter app

Implementazione dell'MVP descritto in [`docs/cv-app/map.md`](../docs/cv-app/map.md).

## Cosa c'è oggi

Questa iterazione contiene il **layer fondamentale** (tickets 01→04):

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
- **Invarianti** (`validation.dart`)
  - Unicità `displayTitle` case-insensitive + trim.
  - Unicità `kind` per sezioni non-custom.
  - Item id univoci dentro le liste.
  - Campi obbligatori (nome/cognome, ruolo+azienda+start, titolo, lingua+livello, nome+ente).
  - `current` xor `endDate`; range date coerenti.
- **Asset GC** al save (`garbageCollectAssets`).
- **`CvRepository`** astratto + `InMemoryCvRepository` (`lib/src/repository/`).
  - Stream reattivi per Libreria/Editor, `Future` per azioni.
  - Naming duplicati coerente col ticket 14 (`<name> (N)`).
  - `ImportResult` sealed: Success/Conflict/Corrupt.

## Cosa **non** c'è ancora

Per iterazione futura, in ordine dei ticket:

- Backend concreti del repository (`path_provider` desktop/mobile, `idb_shim`
  web) — ticket 04.
- Import PDF (`pdfrx` + euristiche) — ticket 05, 10, 12, 13.
- Editor + Libreria + Preview con Bloc/Cubit e `super_editor` — ticket 07, 14.
- Template PDF Classico/Moderno/Minimal (`pdf` + `printing`) — ticket 08.
- Foto profilo + normalizzazione — ticket 09.
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
flutter analyze
flutter test
```
