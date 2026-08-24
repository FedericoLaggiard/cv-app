# Internazionalizzazione (app e CV)

Type: grilling
Status: resolved
Blocked by: 01, 07

## Question

L'MVP deve gestire due assi di internazionalizzazione, potenzialmente indipendenti:

1. **Localizzazione dell'app (UI)** — le label dell'editor, dialog, menu, template thumbnail, messaggi di errore. Solo italiano nell'MVP? Italiano + inglese da subito? Framework (`flutter_localizations` + ARB) sì/no?
2. **CV multilingua** — un utente può volere lo stesso CV in italiano e inglese per candidature diverse. L'MVP lo copre col meccanismo delle **varianti nominate** ("Backend Senior IT", "Backend Senior EN") oppure richiede un supporto esplicito nello schema (campo `language` per variante, o campi multilingua per label/valori)?
3. **Localizzazione dei template PDF** — le label statiche renderizzate dai 3 template (es. "Esperienze", "Formazione", "Skill", "Lingue") sono attualmente in italiano hard-coded. Vanno tradotte per CV in altra lingua? E se sì: seguono l'UI dell'app, il `language` della variante, o una scelta esplicita all'export?
4. **Formati locale-dipendenti**: date (`"YYYY-MM"` è locale-neutro, ma il rendering nei template usa "Gennaio 2023" italiano hard-coded — vedi ticket 08). Vanno tradotte in base alla lingua del CV?

La destinazione della mappa è **spec MVP consegnabile**: la decisione qui fissa se l'i18n entra nell'MVP o resta v2, e se entra parzialmente definisce dove taglia.

## Answer

### Localizzazione UI dell'app

- **Due lingue nell'MVP**: **italiano + inglese**, cablate da subito con `flutter_localizations` + file **ARB** (`app_it.arb`, `app_en.arb`) e generazione via `flutter gen-l10n`. Nessuna libreria terza (SDK-native).
- **Lingua di default = quella del sistema**, con **fallback su inglese** (non italiano) quando il sistema è configurato su una lingua non supportata. Il fallback in inglese massimizza la comprensibilità per un utente che non riconosce la lingua.
- **Switcher manuale in Impostazioni**: nuova schermata `Impostazioni` (accessibile dalla top bar della Libreria via icona ingranaggio) con una **singola voce nell'MVP**: `Lingua interfaccia` → radio `Sistema` / `Italiano` / `Inglese`. La schermata è strutturata come **lista estendibile** (ListView di tile) per accogliere preferenze future senza rework, ma nell'MVP contiene solo questa voce.
- **Persistenza della preferenza**: `shared_preferences` (chiave `ui_locale` con valori `system`/`it`/`en`). **Non** dentro `.cvapp` (che è per-variante), **non** dentro la libreria (che è insieme di varianti): è una preferenza dell'installazione dell'app. Aggiunta minima allo stack del ticket 06.

### CV multilingua

- **Nessun supporto esplicito nello schema**: nessun campo `language` per variante, nessun campo multilingua per label/valori. Il modello dati del ticket 01 resta invariato.
- **Il CV multilingua si esprime via varianti nominate**: "Backend Senior IT" e "Backend Senior EN" sono due `.cvapp` indipendenti nella libreria, seguendo esattamente il pattern di versioning già scelto. L'utente sceglie la convenzione di naming come preferisce (suffisso `IT`/`EN`, sezione della libreria, whatever).
- **Post-MVP (v2+)**: si sta considerando una funzione di **traduzione automatica dei CV via LLM/AI** — l'utente indica lingua sorgente e lingua target, l'assistente genera una nuova variante tradotta. Coerente con la linea "LLM assistant" già presente in Fuori scope (job-tailored + traduzione fanno parte dello stesso capitolo v2).

### Localizzazione dei template PDF

- **Le label statiche dei 3 template** (`Esperienze`/`Experience`, `Formazione`/`Education`, `Skill`/`Skills`, `Lingue`/`Languages`, `Certificazioni`/`Certifications`, mesi nelle date, marker "in corso"/"present") sono **duplicate in italiano e inglese** nel codice dei template, chiavate su un enum `LabelLocale { it, en }`.
- **La scelta della lingua è esplicita al momento dell'export**: il dialog di export mostra un dropdown `Lingua etichette` con valori `Italiano` / `English`, **default = lingua UI corrente dell'app** (che a sua volta segue il sistema o l'override in Impostazioni). L'utente può cambiarla per ogni singolo export.
- Questo rende **indipendente** la lingua UI dell'app dalla lingua delle label del PDF esportato — necessario perché con CV multilingua via varianti il template non può inferire la lingua del contenuto dallo schema.
- **Amendment al ticket 08**: le costanti label italiane hard-coded diventano tabella `Map<LabelLocale, Labels>`; la funzione di rendering dei template accetta `LabelLocale` come parametro. Nessun impatto sul design visivo (font, colori, layout invariati).

### Formati locale-dipendenti

- **Rendering date nei template**: la scelta `Lingua etichette` all'export controlla anche la localizzazione delle date (`"Gennaio 2023"` in IT, `"January 2023"` in EN, `"in corso"` vs `"present"`). Uso `intl.DateFormat` con il locale corrispondente.
- **Dati serializzati nel `.cvapp` restano invariati**: date `"YYYY-MM"` locale-neutre, enum snake_case ASCII (già stabilito in ticket 03). Nessun cambio al formato di file.
- **UI dell'editor**: le date mostrate all'utente (es. nei date picker mese+anno) seguono la **lingua UI** dell'app, non la lingua etichette (che è solo per l'export).

### Live preview PDF e switcher lingua etichette

- La schermata di **live preview PDF** (ticket 07) mostra il dropdown `Lingua etichette` in cima, accanto al selettore template. Cambio della lingua etichette invalida la preview corrente e mostra il banner "Anteprima non aggiornata" con `Rigenera`.
- La lingua etichette **selezionata nella preview** è il default proposto nel dialog di export, ma resta modificabile lì.

### Riepilogo amendment ai ticket già chiusi

- **Ticket 06 (stack)**: aggiunta `flutter_localizations` (SDK Flutter, no dep aggiuntiva) + `intl` (già presente indirettamente via `flutter_localizations`) + `shared_preferences` (BSD-3-Clause, `flutter_community_plus`, licenza OK).
- **Ticket 07 (UX editor)**: nuova schermata `Impostazioni` raggiungibile da icona ingranaggio nella top bar della Libreria; live preview PDF include dropdown `Lingua etichette`; wireframe del ticket 07 restano validi con questa aggiunta di dettaglio.
- **Ticket 08 (template)**: le label diventano tabella `Map<LabelLocale, Labels>`; funzione render dei template prende `LabelLocale` in ingresso; rendering date via `intl` con locale scelto.
