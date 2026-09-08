Fetta verticale #N. Ripara i **guasti puri** delle euristiche di import: formati data non coperti, dizionario titoli incompleto, footer di pagina trattati come contenuto, link spazzatura. Sono difetti validi in qualunque strategia di import, indipendenti dalle decisioni di filosofia. Dipende da: #28. Misurabile con: Slice M.

## Problem Statement

Su un CV reale in formato Europass, `pdf_import_heuristics.dart` produce `Esperienze` con **zero item** e riversa 5 posizioni lavorative in "Da rivedere". Le cause sono banali e indipendenti tra loro:

1. **Date non parsate.** `tryParseFreeTextYearMonth` accetta `Gen 2020` e `01/2020` ma **non** `1 Jun 2024` (giorno + mese + anno), che è il formato di Europass e di molti export. Zero date riconosciute → zero confini di item → `_groupIntoBlocks` restituisce un blocco unico → nessun `EsperienzaItem` creato. **È la causa singola più grossa.**
2. **Dizionario titoli incompleto.** `EDUCATION & TRAINING` non matcha (in `_sectionTitleSynonyms` c'è `education and training`, non la variante con `&`). `ABOUT MYSELF`/`PROFILO` e `SKILLS`/`COMPETENZE` non ci sono affatto: non essendo riconosciuti come heading, **non chiudono la sezione precedente**, e il loro contenuto cola dentro il body della sezione che li precede.
3. **Link spazzatura.** `_urlRe` matcha qualunque `parola.parola`. Sulla riga delle skill (`React.js | Flutter | Node.js | ...`) produce `https://React.js`, `https://Node.js`, `https://Vue.js`, e da un nome puntato tipo `Istituto A.B. Rossi` produce `https://A.B`. Nel CV importato compaiono 9 link inesistenti — visibile a occhio nella sezione Contatti.
4. **Footer di pagina come contenuto.** `Page 1/2` e `Page 2/2` entrano nel flusso come righe normali e finiscono in una `descrizione`.

## Solution

- **Date**: estendere `tryParseFreeTextYearMonth` con il formato **giorno + mese + anno** (`1 Jun 2024`, `30 SEP 2007`, `01/06/2024`), normalizzando a `YearMonth` (il giorno viene scartato: lo schema è mese+anno per il ticket 01). Estendere il dizionario mesi con le abbreviazioni maiuscole già coperte dal `toLowerCase`.
- **Dizionario titoli**: aggiungere le varianti con `&`, e le sezioni oggi assenti — `sommario` (about me / about myself / profilo / profile / summary / chi sono) e `skill` (skills / competenze / competenze tecniche / technical skills / hard skills). Aggiungere `SectionKind.sommario` e `SectionKind.skill` alla mappa dei sinonimi.
- **Heading riconosciuto ma non strutturabile**: come da ticket 13, diventa una **sezione custom col titolo originale**, non un versamento anonimo in "Da rivedere". Questo vale già ora per Lingue; va esteso a Sommario e Skill in attesa della Slice P.
- **URL**: restringere `_urlRe` a un **TLD da allowlist** (`com|org|net|io|dev|it|eu|co|me|ai|app|xyz|info|...`) oppure a match con schema `https?://` esplicito. Un token `React.js` non deve mai diventare un link.
- **Footer/header di pagina**: scartare le righe che matchano un pattern di paginazione (`Page N/M`, `Pagina N di M`, `N/M` isolato) e, più in generale, le righe **identiche o quasi che ricorrono nella stessa posizione su più pagine**.

## User Stories

1. Come utente che importa un CV Europass, voglio che le date `1 Jun 2024 - Current` siano riconosciute, così le mie esperienze diventano item separati invece di un blob.
2. Come utente, voglio che `30 SEP 2007` in Formazione sia riconosciuta, così la voce di studio ha la sua data.
3. Come utente, voglio che `EDUCATION & TRAINING`, `SKILLS` e `ABOUT MYSELF` siano riconosciuti come titoli di sezione, così il contenuto non finisce dentro la sezione sbagliata.
4. Come utente, voglio che nella sezione Contatti compaiano solo link veri, così non devo cancellare a mano 9 voci `https://React.js`.
5. Come utente, voglio che `Page 1/2` non compaia in mezzo alla descrizione di un'esperienza.
6. Come utente con un CV che ha una sezione riconosciuta ma non strutturabile, voglio ritrovarla come sezione custom **col suo titolo originale**, così so cos'era.

## Implementation Decisions

- **Il giorno si scarta, non si conserva**: lo schema (ticket 01) è mese+anno. `1 Jun 2024` → `YearMonth(2024, 6)`.
- **Allowlist TLD, non blocklist di estensioni.** Bloccare `.js`/`.ts` risolve il caso di oggi e non il prossimo (`.py`, `.rs`, `.net` è pure un TLD vero). L'allowlist sbaglia in modo prevedibile: al massimo perde un link con TLD esotico, mai inventa un link da un nome di libreria.
- **Rilevamento footer per ricorrenza posizionale** su documenti multi-pagina, con fallback su regex di paginazione per i monopagina.
- **`_sectionTitleSynonyms` resta un `const` in-code**, non un asset YAML: la Slice I aveva già preso questa decisione e regge (lista piccola, statica, modulo senza dipendenze).
- Nessun cambiamento di filosofia in questa slice: `ruolo`/`azienda`/`nome`/`cognome` restano non compilati. Quella è la Slice P.

## Testing Decisions

- Estendere la tabella di casi di `tryParseFreeTextYearMonth` con i nuovi formati **e i non-formati** che devono continuare a fallire (`32 Jun 2024`, `1 Foo 2024`, `2024`).
- Test dedicato anti-regressione sui link spazzatura: input = la riga skill reale del corpus, atteso = **zero** link.
- Test sul rilevamento footer con fixture a 2 pagine.
- **Il tasso di conversione della Slice M deve salire**, e il numero prima/dopo va riportato nella PR.

## Out of Scope

- Compilare `ruolo`/`azienda`/`nome`/`cognome` (→ Slice P).
- Estrarre livelli CEFR e tag skill strutturati (→ Slice P).
- Passo di revisione (→ Slice O).

## Further Notes

- Questi difetti sono **puri**: valgono sia che l'import resti automatico sia che arrivi il passo di revisione. Vanno chiusi comunque e per primi dopo la metrica.
