# Sub-flow di gestione delle varianti (rinomina, duplica, elimina)

Type: grilling
Status: resolved
Blocked by: 07

## Question

La schermata Libreria (ticket 07) espone su ogni card variante un menu `[⋯]` con le azioni **Rinomina**, **Duplica**, **Elimina**, e la card `Nuova` offre un menu con `Da zero` / `Da PDF` / `Duplica`. Restano da specificare i sub-flow associati:

1. **Rinomina** — dialog, validazione (`variantName` non vuoto, univoco per libreria?), cosa succede al file `<uuid>.cvapp` (rimane invariato, cambia solo il campo interno) e ai nomi di export.
2. **Duplica** — dialog di scelta variante sorgente quando l'azione parte dalla card `Nuova` (elenco varianti + suggerimento del nome della copia); comportamento del nome default (`"<orig> — copia"`, contatore `(2)`, `(3)` in caso di collisione?); nuovo `id` UUID, `createdAt` aggiornato.
3. **Elimina** — dialog di conferma (testuale semplice o "digita il nome per confermare"), **undo** post-eliminazione (toast con "Annulla" tipo import esterno, oppure eliminazione definitiva senza undo), permanenza (file rimosso dalla cartella app-managed / record IndexedDB rimosso subito o soft-delete con GC).
4. **Interazioni cross-piattaforma**: la stessa UX su libreria mobile (bottom-sheet vs dialog) e su web.

## Answer

### Univocità del `variantName`

**Univocità hard, case-insensitive con trim**, all'interno della libreria. Rinomina e creazione (Da zero / Da PDF / Duplica) mostrano **errore inline** se il nome collide con una variante esistente e disabilitano il pulsante di conferma. Il nome è UI-facing e determina il nome di file all'export (`<variantName sanitizzato>.cvapp` da ticket 04); l'identità logica resta l'UUID interno.

### Rinomina

- **Dialog modale** (coerente con `Aggiungi sezione` del ticket 07) con singolo `TextField` pre-popolato col nome corrente, validazione live (non vuoto dopo trim, univoco case-insensitive), azioni `[Annulla] [Salva]`.
- Il file su disco (`<uuid>.cvapp` in cartella app-managed) **non viene rinominato**: cambia solo il campo `variantName` interno. Il nome del file di **export** riflette il nuovo `variantName`.
- Auto-save 800ms standard: la rinomina committa la variante come un normale campo editato.

### Duplica

- **Da menu `[⋯]` su card variante**: nessun dialog di scelta sorgente (la sorgente è la card stessa). Dialog con nome default `<origName> (2)` — se `(2)` collide, `(3)`, `(4)` … primo slot libero (matcha pattern `^<origName> \((\d+)\)$` case-insensitive e prende il prossimo). Utente può editare prima di confermare; validazione univocità come sopra.
- **Da card `Nuova` → `Duplica`**: dialog a due campi/step — `Dropdown "Variante sorgente"` (elenco varianti, ordinato per `updatedAt` desc come la libreria) + `TextField "Nome"` che si auto-aggiorna col naming incrementale quando cambia la sorgente. Editabile prima di confermare.
- Alla conferma: nuovo `id: UUID v4`, `createdAt = updatedAt = now()`, `variantName` = nome scelto, tutto il resto (sections, assets) copiato per valore. Nessuna relazione persistita fra originale e copia.

### Elimina

- **Dialog conferma semplice**: `Elimina "<variantName>"? Questa azione non può essere annullata. [Annulla] [Elimina]`. Il pulsante `Elimina` è tinto destructive (rosso).
- **Hard-delete immediato** al conferma: rimozione del file `<uuid>.cvapp` dalla cartella app-managed (desktop/mobile) o del record dall'object store `variants` (web), + GC degli asset embed nel file (già embed nel JSON, spariscono con esso). **Nessun undo, nessun cestino, nessun toast Annulla** — coerente con la filosofia MVP "no backup automatico" del ticket 04.
- Se la variante eliminata era aperta nell'editor, l'app torna alla schermata Libreria.

### Interazioni cross-piattaforma

- **Desktop / web-desktop (finestra ≥ 900px)**: menu `[⋯]` sulla card apre un **popup menu** ancorato all'icona, con voci Rinomina / Duplica / Elimina. Dialog modali centrati per rinomina/duplica/conferma-elimina.
- **Mobile / web-mobile (finestra < 900px)**: menu `[⋯]` sulla card apre un **bottom sheet** con le stesse azioni (coerente con l'indice bottom-sheet del ticket 07). I dialog rinomina/duplica/conferma-elimina restano dialog modali (non bottom sheet) per non confondere il livello di gerarchia.
- Nessun long-press su card in questo giro: il tap breve apre la variante nell'editor, l'icona `[⋯]` è la sola porta d'accesso alle azioni di gestione — riduce ambiguità e testabilità cross-piattaforma.

### Edge case: collisione di nome all'import esterno

Amendment al ticket 04 (auto-import silenzioso di `.cvapp` esterno via doppio-click / share-in): se il `variantName` del file importato collide con una variante esistente in libreria (univocità hard), l'app **auto-rinomina** applicando il suffisso `(2)`, `(3)`, … con la stessa regola di Duplica, e mostra il toast informativo standard con azione "Annulla" (che annulla l'import intero, come già previsto dal ticket 04). L'`ImportResult.conflict` resta riservato a collisione di **UUID** (stesso file re-importato), non di nome.
