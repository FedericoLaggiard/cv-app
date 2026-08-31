# Mutation testing notturno su pipeline remota

Type: grill-with-docs
Status: open
Depends on: 18 (CI locale), 20 (refactoring validation)

## Question

Il mutation testing è uno degli step richiesti dal ticket 18 ma **non è
eseguibile in locale con tempi ragionevoli**. Va spostato su una pipeline
remota schedulata, con un quality gate sul mutation score.

## Il fatto che ha spostato questo step fuori dalla CI locale

Misurato su una copia della codebase (agosto 2026), con `mutation_test` 1.8.0
puntato su `lib/src/domain/` e comando di test `flutter test test/domain`:

```
Found 719 mutations in 11 source files!
lib/src/domain/validation.dart : 93 mutations
stima a regime: ~90 minuti per un giro completo
```

**~7,5 secondi per mutante × 719 mutanti ≈ 90 minuti.** Su `pre-push`
significherebbe un divieto di push; l'esito prevedibile è la disinstallazione
dell'hook dopo due giorni.

Il baseline dello score **non è stato completato** (il run è stato interrotto
al 19%): va misurato all'apertura di questo ticket.

## Decisioni già prese

### Tool

**`mutation_test`** (pub.dev, Dart puro, `dart pub global activate
mutation_test`). Unica opzione viva per Dart: muta i sorgenti per sostituzione
testuale con regex e rilancia un comando di test configurabile. L'alternativa è
il mutation testing manuale, che non è automatizzabile.

### Perimetro

**Solo `lib/src/domain/`** — logica pura, ben isolata. Mutare i widget produce
mutanti equivalenti a valanga e fa esplodere i tempi senza aggiungere segnale.

Comando di test: **`flutter test test/domain`**, non l'intera suite. Un mutante
nel dominio deve essere ucciso dai test del dominio; attribuire l'uccisione a un
widget test moltiplicherebbe i tempi e falserebbe la lettura.

### Dove gira: GitHub Actions su repo pubblico

Il repo `FedericoLaggiard/cv-app` **diventa pubblico** (deciso dall'utente).

Motivo, dal report allegato:

| | Free (privato) | Pubblico |
|---|---|---|
| Minuti/mese | 2.000 | illimitati |
| Job notturno 90 min × 30 gg = 2.700 min | **$4,20/mese**, quota esaurita al 22° giorno | **$0** |
| Manutenzione | — | nessuna |

Il vincolo dell'utente è **costo zero non negoziabile**, e su repo privato con
piano Free il job sfora del 35% mandando l'account in blocco (o in addebito, se
c'è una carta registrata).

Alternative scartate:
- **Self-hosted runner sul Mac**: costo zero e repo privato, ma richiede il Mac
  acceso e una toolchain in più da mantenere. Era il fallback se il repo fosse
  dovuto restare privato.
- **`launchd` locale notturno**: zero infrastruttura, ma nessuna notifica e
  nessuno storico. Un job che gira e che nessuno guarda non è un quality gate.
- **GitLab CI** (400 min/mese) e **CircleCI** (niente macOS): esclusi.

Runner: `ubuntu-latest`. `flutter test` unit/widget non richiede display né
emulatore.

### Quality gate

- Baseline misurato per primo, **poi** si fissa la soglia. Nessun numero
  scelto a priori.
- Regola: **soglia = baseline arrotondato per difetto ai 5 punti**
  (es. 73% → 70%). Margine sufficiente per il rumore fra run, numero leggibile,
  e ogni stretta successiva è un gesto esplicito.
- **Obiettivo di lungo periodo: 80%.**
- **Non si insegue il 100%.** Esistono i *mutanti equivalenti* — mutazioni che
  non cambiano il comportamento osservabile e che nessun test può uccidere
  (`<` → `<=` su un confine irraggiungibile per il tipo, `&&` → `||` in una
  guardia dove il secondo operando è già implicato dal primo). `mutation_test`
  muta per regex, quindi ne genera parecchi. Inseguire lo zero-sopravvissuti
  porta a scrivere test che documentano l'implementazione invece del
  comportamento, cioè a rendere il codice non refattorizzabile. I progetti seri
  stanno fra il 70% e l'85%.

## Aree da grigliare all'apertura

1. **Ridurre i 719 mutanti prima di schedulare qualsiasi cosa.** Il report
   segnala che `mutation_test` sa restringere il perimetro con la coverage
   `lcov` e con whitelist di righe: i mutanti su righe non coperte da test
   sopravvivono per definizione e non insegnano nulla. Quanto scende il numero?
2. **Orario e frequenza**: ogni notte, o solo quando `lib/src/domain/` è
   cambiato dall'ultimo run?
3. **Chi guarda il risultato**: notifica su fallimento (email GitHub? issue
   automatica?) — senza questo il gate è decorativo.
4. **Rapporto con `main`**: il gate blocca un merge, o segnala e basta?
5. **Cosa altro passa a pubblico**: rendere il repo pubblico ha conseguenze
   oltre la CI (history, eventuali dati nei commit passati). Va verificato che
   la history non contenga nulla di personale prima dello switch.
6. **Setup Flutter in CI**: `subosito/flutter-action` con cache; il tempo di
   setup non è documentato dalle fonti primarie e va misurato. Cache 10 GB per
   repo, eviction a 7 giorni di mancato accesso — una run notturna la tiene
   viva.

## Report

[assets/22-mutation-testing-ci-report.md](assets/22-mutation-testing-ci-report.md)
