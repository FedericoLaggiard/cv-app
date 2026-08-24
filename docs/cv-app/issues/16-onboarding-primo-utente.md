# Onboarding del primo utente

Type: grilling
Status: resolved
Blocked by: 07

## Question

Il ticket 07 stabilisce che la schermata Libreria in stato vuoto mostra CTA verticali (`Crea da zero` / `Importa PDF`). Resta da decidere se l'MVP aggiunge un livello di onboarding più esplicito per il primo utente:

1. **Tour guidato all'apertura**: sequenza di card/dialog che spiega il modello (varianti = versioning, no cloud sync, export PDF con 3 template, import PDF conservativo), skippabile.
2. **Suggerimenti contestuali**: tooltip/coach-mark alla prima apertura dell'editor (`Questa è una sezione fissa`, `Trascina qui per riordinare`, `Le sezioni obbligatorie hanno il badge ⚠`, `Ricordati di aggiungere una variante per ogni tipo di candidatura`).
3. **Contenuto pre-caricato**: la libreria non è mai vuota al primo avvio ma contiene una **variante di esempio** ("Esempio Mario Rossi") che l'utente può ispezionare/duplicare/eliminare.
4. **Solo CTA della libreria vuota** (ticket 07): niente onboarding esplicito, la scoperta avviene naturalmente muovendosi nell'app.
5. **Rilevamento primo avvio**: come lo distingui? Flag `first_run` in `shared_preferences`? Assenza di varianti nella libreria?

## Answer

### Forma dell'onboarding

**Tour guidato skippabile a 5 card** al primo avvio, presentato come **overlay a schermo intero** che oscura la schermata Libreria dietro (semitrasparente, backdrop `Colors.black54`). Card centrata con:

- **Desktop / web-desktop (≥ 900px)**: frecce laterali (`◀` `▶`) per navigare, `Salta` in alto-destra, dot indicator in basso, pulsante primario in basso-destra (`Avanti` / `Inizia`).
- **Mobile / web-mobile (< 900px)**: swipe orizzontale come navigazione primaria, gli stessi controlli restano tappabili.

Nessun tour guidato dentro l'editor (no coach-mark contestuali nell'MVP) e nessuna variante di esempio pre-caricata: la Libreria al primo avvio resta vuota dopo la chiusura del tour, con le CTA verticali del ticket 07.

### Contenuto delle 5 card

Titoli e testi sono localizzati in italiano e inglese (via ARB, ticket 15).

1. **Benvenuto** — "Benvenuto in CV app. I tuoi dati restano sul tuo dispositivo: nessun account, nessun cloud, nessuna sincronizzazione automatica."
2. **Varianti del CV** — "Crea più varianti del tuo CV per candidature diverse: una per ruolo, una per settore, una in un'altra lingua. Ogni variante è un file indipendente."
3. **Import da PDF** — "Importa un CV esistente in PDF per iniziare rapidamente. L'import funziona meglio con CV lineari a una colonna: layout creativi o PDF scansionati non sono ancora supportati."
4. **Export PDF con 3 template** — "Esporta il CV finale in PDF scegliendo fra 3 template: Classico, Moderno, Minimal."
5. **Impostazioni e lingua** — "Dalle Impostazioni puoi cambiare la lingua dell'interfaccia e scegliere la lingua delle etichette del PDF esportato in modo indipendente."

Ogni card include un titolo, un corpo di 1–2 frasi, e un'illustrazione/icona semplice (icone Material/Cupertino a due colori, no immagini raster — mantiene bundle leggero e cross-piattaforma).

### Trigger e persistenza

- Flag `onboarding_completed: bool` in `shared_preferences` (nuova chiave, insieme a `ui_locale` del ticket 15).
- Il tour parte solo se `onboarding_completed == false`; **al primo avvio dopo installazione** la chiave è assente → tour parte.
- Il flag viene settato a `true` sia quando l'utente **completa** l'ultima card (`Inizia`) sia quando **skippa** con `Salta`. Non ci sono stati intermedi: chiuso è chiuso.
- Voce **`Rivedi tour`** nella schermata Impostazioni (ticket 15) — cliccarla riapre l'overlay dalla prima card, senza toccare `onboarding_completed`. Consente all'utente di riguardare le spiegazioni senza reset dell'app.
- Chiudere l'overlay con Esc (desktop) o back button (mobile) equivale a `Salta`.

### Amendment ai ticket chiusi

- **Ticket 07 (UX editor)**: la schermata Libreria monta l'overlay del tour al primo avvio (check di `onboarding_completed` all'apertura dell'app). La schermata Impostazioni (già introdotta dal ticket 15) guadagna una seconda voce nell'MVP: `Rivedi tour` (tile con azione `Apri`). La lista estendibile ora contiene due voci — `Lingua interfaccia` e `Rivedi tour`.
- **Ticket 15 (i18n)**: aggiunta chiave `onboarding_completed` in `shared_preferences`; testi delle 5 card localizzati IT+EN in `app_it.arb` / `app_en.arb`.
