# UX della revisione dell'import assistito

Type: prototype
Status: closed
Blocked by: 07, 10

## Question

La [ricerca 05](05-ricerca-import-pdf.md) ha eliminato l'auto-mapping completo e ha lasciato in piedi **l'import assistito**: estrai testo (con bounding box), mostra all'utente il PDF sorgente affiancato al testo estratto, l'utente riversa i pezzi nei campi dello schema.

Prototipare l'UX di questa schermata di revisione.

Punti da chiudere:
- Layout: split-view PDF ↔ estratto ↔ campi schema? tre pannelli o due?
- Interazione di trasferimento: drag-drop di blocchi? selezione + tasto "assegna a…"? copy-paste puro?
- Come si aggiungono/rimuovono esperienze/formazione/certificazioni durante la revisione (interseca con [ticket 07](07-ux-editor.md)).
- Come si mostrano **suggerimenti automatici** (se le euristiche di [ticket 13](13-euristiche-mapping-pdf.md) producono candidati): come si mostra la confidence? soglia sotto la quale non suggeriamo nulla?
- Cosa succede su PDF vuoti/illeggibili/cifrati: messaggi, fallback a "riempi a mano".
- Differenza tra desktop (schermo grande, drag-drop naturale) e mobile (schermo piccolo, split-view costoso).

Output atteso: outline delle schermate + wireframe testuali linkati come asset.

## Input

- [Ticket 07 (UX editor)](07-ux-editor.md) per convenzioni condivise.
- [Ticket 10 (scelta libreria PDF)](10-scelta-libreria-pdf.md) — l'API scelta condiziona quali "segnali" possiamo mostrare (solo testo+bbox vs anche font/stile).

## Risoluzione

**Fuori scope MVP → v2.**

Nel [ticket 10](10-scelta-libreria-pdf.md) l'utente ha esplicitato la strategia di import per l'MVP: **auto-import puro**, senza UX di revisione dedicata. L'editor normale del CV è la superficie di correzione; i frammenti non mappati vengono scartati e l'utente li reinserisce a mano nell'editor.

Di conseguenza la schermata di revisione affiancata (PDF ↔ testo estratto ↔ campi) descritta in questo ticket **non serve nell'MVP**. Il ticket viene mantenuto come traccia per la v2, dove è previsto l'import assistito come alternativa opzionale all'auto-import per PDF su cui l'auto-mapping produce risultati scarsi.

Riaprire quando si affronterà la v2 dell'import.
