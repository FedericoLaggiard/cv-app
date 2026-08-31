# Refactoring di `_structuralErrors` (complessità ciclomatica 33)

Type: implementation
Status: open
Priority: alta — dichiarato bloccante dall'utente
Depends on: 19
Blocks: 18

## Question

`_structuralErrors` in `lib/src/domain/validation.dart` ha **complessità
ciclomatica 33**, oltre tre volte la soglia di 10 fissata dal ticket 18 per il
dominio. È l'unico ostacolo strutturale all'attivazione del quality gate senza
deroghe.

## Perché conta più del numero

Due ragioni indipendenti, e la seconda è quella vera:

1. Il gate del ticket 18 non ammette esclusioni: finché questa funzione esiste
   così, la pipeline non può essere installata.
2. `validation.dart` è nel `domain/`, cioè nel perimetro del mutation testing
   (ticket 22). Una funzione a 33 rami è precisamente il posto dove i mutanti
   sopravvivono: la complessità e la debolezza dei test sono lo stesso
   problema misurato da due strumenti diversi. Da sola, `validation.dart`
   genera **93 dei 719 mutanti** del dominio.

## Direzione proposta

Split per tipo di sezione: la funzione oggi discrimina su `kind` e applica
regole strutturali diverse per ciascuno. Un dispatch verso validatori
per-`kind` porta ogni ramo sotto soglia e rende i test unitari indirizzabili
sul singolo tipo — che è anche ciò che serve al mutation testing per uccidere
i mutanti.

Da decidere in implementazione, non qui.

## Non-goal

- Non cambiare il **comportamento osservabile** della validazione: i test
  esistenti (`validation_test.dart`, `validation_structure_test.dart`) devono
  restare verdi senza modifiche. È un refactoring, non una revisione delle
  regole.
- Non toccare `analyzeMissingRequired` (CC 16, in `missing_required.dart`):
  è anch'essa sopra soglia e va sistemata, ma è un lavoro distinto — se resta
  sopra 10 dopo questo ticket, il gate del 18 non passa comunque, quindi va
  incluso nel perimetro. **Da confermare in apertura del ticket.**

## Criteri di accettazione

- [ ] `_structuralErrors` e ogni funzione risultante hanno CC < 10.
- [ ] `analyzeMissingRequired` ha CC < 10.
- [ ] `dart run dart_code_linter:metrics analyze lib/src/domain` non riporta
      violazioni con soglia 10 (a parte quelle di `cv_section.dart`, ticket 21).
- [ ] Test di validazione verdi **senza modifiche ai test**.
