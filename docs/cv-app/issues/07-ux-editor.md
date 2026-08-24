# UX dell'editor del CV

Type: prototype
Status: resolved
Blocked by: 01

## Question

Prototipare (outline testuale + wireframe rough) l'**UX dell'editor** che l'utente usa per creare/modificare una variante di CV.

Punti da chiudere:
- Navigazione tra sezioni: sidebar/tab/stepper/scroll unico?
- Form guidati per campi tipizzati vs area libera per testo lungo.
- Come si aggiungono/riordinano/rimuovono voci in una sezione (es. tante esperienze).
- Come si aggiungono sezioni custom.
- **Live preview del template selezionato**: sì/no; se sì, dove (pannello laterale desktop, tab su mobile)?
- Cambio template sull'anteprima senza modificare i dati.
- Feedback su campi obbligatori mancanti / validazione.
- Differenze UX tra desktop (grande), tablet, mobile (piccolo).

Output atteso: outline delle schermate principali + linked file con wireframe testuali/schizzi.

## Vincoli decisi a monte

- Schema dati fisso e rich text = Markdown definiti in [ticket 01](01-schema-dati-cv.md). Considerare quel documento come input.

## Answer

**Layout largo (desktop nativo + web desktop)**: due colonne fisse — sidebar-indice a sinistra (jump-to, non filtra) + editor a scroll unico al centro. Nessuna terza colonna. La preview PDF è una **route/schermata a piena pagina** che si apre dal pulsante `Anteprima` in top bar: toolbar in alto con selector template a thumbnail + banner "Anteprima non aggiornata" (rigenerazione manuale), foglio A4 centrato sotto. Si torna all'editor con `← Editor` in top bar; i dati non vengono toccati dal cambio template.

**Voci delle sezioni-lista** (Esperienze, Formazione, Lingue, Certificazioni) **sempre espanse** a piena altezza nel flusso, nessun collapse — coerente con lo spirito "vedo tutto".

**Le sezioni (Anagrafica, Contatti, Sommario, Esperienze, …) sono invece collassabili** come blocco intero, con un chevron `▾/▸` nell'header (click sull'header o sul chevron alterna lo stato). Default = tutte espanse. Il collapse riguarda solo lo stato **di visualizzazione**: non viene serializzato in `.cvapp` (è pura preferenza di UI, per-varianti in memoria). Comodità: `Comprimi tutte` / `Espandi tutte` nella sidebar-indice su desktop e nell'header del bottom sheet su mobile. Jump-to dall'indice **espande automaticamente** la sezione se collassata, per evitare di scrollare al vuoto. Un badge ⚠ nell'header della sezione collassata resta visibile, perché segnala obbligatori mancanti dentro un blocco che l'utente non sta vedendo.

**Editing rich text** con `super_editor` WYSIWYG (ticket 06), toolbar sempre visibile in cima al campo attivo su desktop; sopra la tastiera su mobile.

**Riordino**: drag handle `⋮⋮` primario (solo l'handle avvia il drag, non l'intera card) + menu contestuale `[⋯]` con "Sposta su/giù/in cima/in fondo" come fallback accessibile. Vale sia per l'ordine globale delle sezioni sia per le voci dentro sezioni-lista. Su mobile: long-press → drag.

**Aggiunta**: doppia esposizione dei "+". Sezione custom o ripristino di una fissa rimossa: bottone in fondo allo scroll **e** nella sidebar-indice, apre un unico dialog `Aggiungi sezione` che elenca le fisse non presenti (radio) + "Sezione personalizzata" (titolo libero). Voce lista: bottone in header sezione **e** in coda alla lista.

**Validazione obbligatori**: marker soft (badge ⚠) nell'indice, sull'header sezione e sull'header voce; nessun blocco durante l'editing; dialog di riepilogo dei mancanti al momento dell'export PDF con opzione "Esporta comunque".

**Salvataggio**: auto-save con debounce ~800ms (già in ticket 04) + indicatore in top bar `Salvato ✓ / Salvataggio… / ⚠ Errore [Riprova]`.

**Mobile**: layout a colonna singola, indice come bottom sheet a comparsa (hamburger), anteprima PDF come route dedicata a schermo intero — stessa forma del desktop, senza differenze concettuali fra i due. Toolbar Markdown fissata sopra la tastiera software.

**Avvio app**: schermata **Libreria** con card variante (nome + "aggiornato <relativo>" + [Apri] + menu [⋯] con Duplica/Rinomina/Esporta/Elimina) + card `Nuova` che apre menu tre-opzioni (Da zero / Da PDF esistente / Duplica una variante). Stato vuoto con CTA verticali.

**Rimossa dai punti del ticket**: il tema "differenze desktop/tablet/mobile" viene risolto trattando *desktop nativo e web desktop come paritari* (stesso layout largo) e *mobile come layout a sé* (colonna singola + bottom sheet). L'anteprima PDF è **route piena su entrambi**, quindi non è più una differenza cross-form-factor. Tablet non trattato come categoria separata: eredita il layout largo quando la larghezza della finestra è ≥ 900 px, altrimenti il layout mobile.

Wireframe testuali e outline schermate completi: [assets/07-ux-editor-wireframes.md](assets/07-ux-editor-wireframes.md).
