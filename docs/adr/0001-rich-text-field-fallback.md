# ADR 0001 — `RichTextField` usa il fallback TextField+toolbar, non `super_editor`

Stato: accettata. Ticket: [Spec C — Editor Markdown](https://github.com/FedericoLaggiard/cv-app/issues/22) (amendment implicito al ticket 06).

## Contesto

Il ticket 06 sceglie `super_editor` + `super_editor_markdown` come libreria
primaria per l'editing rich text, con un fallback esplicitamente
pre-approvato: se `super_editor` risulta instabile, `RichTextField` può
essere reimplementato internamente con `TextField` + toolbar custom, a
patto di mantenere la stessa API pubblica `(value, onChanged, focusNode,
key)`.

## Decisione

Slice C implementa `RichTextField` con l'**Approccio A (fallback)** fin da
subito, non come rimedio a un problema incontrato in produzione ma come
scelta di ingegneria per questa slice:

- `super_editor` (0.3.0-dev.39) è una libreria pre-1.0 con API di document
  model, composer e serializzazione ampia e in gran parte non documentata
  nei dettagli operativi (inserimento link, undo/redo nativo, incolla come
  testo semplice, posizionamento toolbar sopra IME). Integrarla
  correttamente su tutte le piattaforme target (iOS, Android, Web, macOS)
  richiede superficie di test manuale che questa slice non ha modo di
  coprire con la stessa affidabilità di un `TextField` nativo Flutter.
- Il Markdown è lo storage nativo del `.cvapp` (ticket 03): con
  `TextField` il testo digitato *è già* il Markdown salvato, senza nessun
  passaggio di serializzazione. Questo elimina una classe intera di bug di
  roundtrip (fedeltà bold/italic/liste/link) che un document model
  introdurrebbe.
- La API pubblica di `RichTextField` resta identica a quella prevista per
  `super_editor`, quindi lo swap resta possibile in una slice futura senza
  toccare i chiamanti (`SommarioForm`, `SkillForm`, `CustomSectionForm`).

## Conseguenze

- **Incolla testo formattato** (user story 5 del ticket): non preservato.
  `TextField` non espone clipboard rich text; qualunque incolla arriva già
  come testo semplice. Rende la user story 6 ("incolla come testo puro")
  triviale, ma la 5 non è soddisfatta con questa implementazione.
- **Heading Markdown**: non esposti in toolbar (erano comunque "differiti"
  dal ticket).
- **Undo/redo**: usa `UndoHistoryController` di Flutter (stack nativo del
  framework), non quello di `super_editor` — coerente con lo spirito della
  decisione originale ("non introdurne uno custom").
- Le dipendenze `super_editor` / `super_editor_markdown` restano dichiarate
  in `pubspec.yaml` (ticket 06) per un'eventuale slice futura che le
  riattivi; nel codice attuale non sono importate.

## Alternative scartate

- **`super_editor` integrato subito**: scartata per il rischio di
  instabilità cross-piattaforma non verificabile in questa slice (vedi
  Contesto).
- **Nessuna toolbar, solo scorciatoie da tastiera**: scartata, viola la
  user story esplicita "toolbar sempre visibile".
