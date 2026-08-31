# Bonifica: registry pub.dev, upgrade SDK, debito di analyze e test rossi

Type: implementation
Status: open
Blocks: 18 (CI locale), 20, 21

## Question

Portare la codebase a uno stato in cui i quality gate del ticket 18 possono
essere attivati **senza deroghe**. Tre lavori che sono lo stesso lavoro visto
da tre angoli — l'upgrade dell'SDK cambia l'output dell'analyze, che cambia
cosa c'è da bonificare — e vanno quindi eseguiti insieme, in un solo branch.

## 1. Rimozione del mirror pub aziendale

**Problema**: `pubspec.lock` e `.dart_tool/package_config.json` risolvono i
pacchetti da `artifactory.gbm.lan`, non da `pub.dev`. La causa è
`PUB_HOSTED_URL` impostata nel profilo shell della macchina di sviluppo (serve
per i progetti di lavoro, non va rimossa da lì).

**Decisione**: il progetto si isola dalla configurazione della macchina.

- Rigenerare `pubspec.lock` con `PUB_HOSTED_URL=https://pub.dev flutter pub get`.
- Verificare che il lock non contenga più host diversi da `pub.dev`.
- Il `Makefile` del ticket 18 esporterà `PUB_HOSTED_URL` su tutti i target e il
  target `check-registry` impedirà il rientro.

**Rischio da verificare per primo**: che `dart_code_linter` e `husky` si
risolvano correttamente da pub.dev sulla macchina di sviluppo.

## 2. Upgrade all'ultima Flutter stable

**Policy dichiarata**: il progetto deve girare **sempre sull'ultima versione
stable di Flutter**, e le librerie devono funzionare con quell'SDK
**possibilmente senza pinning**.

Stato attuale: `environment: sdk: ^3.11.0`, con tre commenti in `pubspec.yaml`
che pinnano deliberatamente `pdf`, `printing` e `freezed` a versioni vecchie
*proprio per restare su Dart 3.11*.

**Da fare**:

- Alzare il vincolo SDK all'ultima stable.
- Rimuovere i pin difensivi su `pdf`, `printing`, `freezed` e portarli
  all'ultima versione compatibile.
- Rivalutare il pin stretto su `super_editor`
  (`>=0.3.0-dev.31 <0.3.0-dev.40`): resta legittimo perché l'API è pre-1.0 e
  le breaking arrivano in punto, ma va verificato con l'SDK nuovo.
- Aggiornare i commenti in `pubspec.yaml` che documentano pin non più validi.

**Dato di partenza incoraggiante**: con Flutter 3.47.2 / Dart 3.13 il
`pub get` risolve già oggi con i vincoli attuali e l'analyze dà 13
segnalazioni. Il salto è economico.

**Amendment ticket 06**: le versioni scelte in quel ticket vengono superate.
Le *scelte di libreria* restano valide; cambiano solo i vincoli di versione.

## 3. Azzeramento del debito di analyze

Target: `flutter analyze --fatal-infos --fatal-warnings` **pulito**.

Segnalazioni note (misurate con Flutter 3.47.2, da rimisurare su `main` dopo
l'upgrade):

- `lib/src/ui/editor/editor_screen.dart:412` — `onReorder` deprecato dopo
  v3.41.0-0.0.pre, va sostituito con `onReorderItem` (che aggiusta `newIndex`
  per l'item rimosso: attenzione, non è un rename meccanico).
- `test/ui/editor/editor_bloc_test.dart` — 12 `invalid_override`: i fake
  `_CountingRepo` e `_FailingSaveRepo` non dichiarano i tipi di ritorno, che
  vengono inferiti `dynamic` e non soddisfano il contratto `CvRepository`.
  Fix: annotare esplicitamente i tipi di ritorno.

## 4. Test rossi

Target: `flutter test` **verde**.

- `test/ui/editor/editor_bloc_test.dart` — non compila (stessa causa del
  punto 3).
- `test/ui/editor/editor_screen_test.dart` — "auto-save aggiungere una voce
  vuota non rompe il salvataggio", da diagnosticare.

**Da verificare**: entrambi i fallimenti sono stati osservati con Flutter
3.47.2, più recente di quella dichiarata dal progetto. Vanno rimisurati dopo
l'upgrade del punto 2, che potrebbe risolverli o cambiarne la natura.

## Criteri di accettazione

- [ ] `pubspec.lock` non contiene host diversi da `pub.dev`.
- [ ] `flutter --version` è l'ultima stable e `pubspec.yaml` la riflette.
- [ ] Nessun pin difensivo su `pdf`, `printing`, `freezed`.
- [ ] `flutter analyze --fatal-infos --fatal-warnings` → 0 segnalazioni.
- [ ] `flutter test` → tutti verdi.
- [ ] `dart_code_linter` e `husky` si risolvono da pub.dev.
