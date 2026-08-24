# Euristiche di mapping testo estratto → schema CV

Type: grilling
Status: closed
Blocked by: —  <!-- 10 chiuso -->

## Perimetro aggiornato (post-10)

Dal [ticket 10](10-scelta-libreria-pdf.md):
- Strategia di import MVP = **auto-import puro** (nessuna UX di revisione). Le euristiche devono essere **conservative**: mappare solo con alta certezza, altrimenti lasciare il campo vuoto (l'utente compila nell'editor normale).
- Nessun confidence score visibile all'utente (soglia binaria interna: mappa / non mappa).
- Libreria = `pdfrx` → **niente font metadata**; usare come proxy geometrici l'**altezza del bounding box carattere** (proporzionale a font size) e la **spaziatura verticale** sopra/sotto un blocco per distinguere titoli da corpo.

## Question

L'import assistito ([ticket 11](11-ux-import-assistito.md)) può suggerire **automaticamente** a quale sezione dello schema appartiene un blocco di testo estratto, e l'utente conferma/corregge. Che euristiche usiamo, considerando che siamo **on-device senza LLM**?

Punti da chiudere:
- Riconoscimento titoli di sezione: match testuale su un dizionario multilingua (Esperienze/Experience/Erfahrung…)? parsing di font-size relativo (solo se la libreria scelta lo espone)? posizione + spaziatura verticale?
- Riconoscimento **date** (mese+anno) e range temporali → attribuzione automatica a Esperienze/Formazione.
- Riconoscimento **contatti** (email, telefono, URL LinkedIn/GitHub) via regex → sezione Contatti.
- Come rappresentiamo la "confidence" di un suggerimento (soglia binaria mostra/nascondi? punteggio numerico? ranking dei top-3?).
- Cosa NON tentiamo di riconoscere automaticamente nell'MVP (skill? lingue? certificazioni?).
- Fallback: se le euristiche falliscono, l'UX di [ticket 11](11-ux-import-assistito.md) deve continuare a funzionare (assistito manuale puro).

Output atteso: lista delle euristiche implementate nell'MVP + criteri di confidence + perimetro di ciò che restiamo consapevolmente incapaci di suggerire.

## Input

- [Ticket 10 (libreria PDF)](10-scelta-libreria-pdf.md) — determina quali segnali (font, bounding box, ecc.) sono disponibili.
- [Ticket 01 (schema dati)](01-schema-dati-cv.md) — sezioni e campi target.

## Risoluzione

### Filosofia

Euristiche **conservative**: precisione > recall. Meglio lasciare un campo vuoto (l'utente lo compila nell'editor) che mettere il dato sbagliato (l'utente deve disfarlo). Nessun confidence score visibile all'utente: soglia binaria interna mappa/non-mappa. I "leftover" — sia sezioni riconosciute ma non strutturate, sia testo non attribuito — finiscono in **sezioni custom** (meccanismo del ticket 02), coerenti col fatto che l'editor normale è l'unica superficie di correzione.

### Architettura della pipeline

**Ibrida in tre livelli, applicata nello stesso passaggio sul testo estratto da `pdfrx`**:

1. **Signal-first globale** — regex sull'intero testo per pattern ad alta certezza, indipendenti dalle sezioni. Riempie campi in Contatti. Il testo consumato dai match viene **de-duplicato** (rimosso dal buffer che alimenta i leftover).
2. **Section-first con blocchi** — cerca titoli di sezione con dizionario multilingua + isolamento + proxy geometrico. Per ogni blocco riconosciuto: se sezione strutturata parsabile → riempi la sezione fissa; altrimenti → **sezione custom** con il titolo originale e contenuto raw come Markdown.
3. **Fallback "Da rivedere"** — tutto il testo non attribuito a nessun blocco finisce in un'unica **sezione custom "Da rivedere"** (o vuota se sotto una soglia minima di caratteri). Non si perde nulla di ciò che è nel PDF.

### Ambito linguistico

Dizionario titoli sezione: **italiano + inglese**. Ogni sezione fissa ha una lista di sinonimi noti (es. Esperienze: "Esperienze", "Esperienze lavorative", "Esperienze professionali", "Experience", "Work experience", "Professional experience", ecc.). Estensione ad altre lingue → v2.

### Riconoscimento titoli di sezione (section-first)

Un token di testo è considerato titolo di sezione **se e solo se** soddisfa **tutte e tre** le condizioni (max precision):

1. **Match dizionario**: match esatto della parola/frase (case-insensitive) contro il dizionario italiano+inglese.
2. **Isolamento sulla riga**: il match appare **da solo sulla riga**, o su una riga breve (< 30 caratteri) senza punteggiatura finale. Rifiuta i paragrafi in cui la parola è embedded.
3. **Proxy geometrico**: altezza del bounding box carattere superiore alla mediana del corpo del documento (usa `charRects` di `pdfrx` come proxy di font size).

**Fallback anti-disastro**: se il documento produce **≥ 2** titoli riconosciuti → ci fidiamo, section-first attivo. Se ne produce **0 o 1** → disabilitiamo il section-first, tutto il testo (meno i Contatti da signal-first) finisce in "Da rivedere". Evita che un singolo falso positivo strutturi male l'intero CV.

### Signal-first: pattern e destinazioni

Nota importante: **Contatti non ha campi dedicati per LinkedIn/GitHub/sito** — c'è una lista generica `Link[]` di `{label, url, icon?}` (ticket 01).

| Pattern (regex indicativa) | Destinazione |
| --- | --- |
| **Email** `[\w.+-]+@[\w-]+\.[\w.-]+` | `Contatti.email` |
| **Telefono** cifre con optional `+` prefisso e separatori, ≥ 8 cifre totali | `Contatti.telefono` |
| **LinkedIn URL** `(?:https?://)?(?:www\.)?linkedin\.com/in/[\w-]+/?` | `Contatti.Link[]` con `{label: "LinkedIn", url, icon: "linkedin"}` |
| **GitHub URL** `(?:https?://)?(?:www\.)?github\.com/[\w-]+/?` | `Contatti.Link[]` con `{label: "GitHub", url, icon: "github"}` |
| **URL generico** (dopo aver escluso i due sopra) `https?://[\w.-]+\.[a-z]{2,}(?:/\S*)?` | `Contatti.Link[]` con `{label: hostname o "Sito web", url}` |

**Non tentiamo di riempire automaticamente**:
- **Nome/cognome**: nessuna regex affidabile; falsi positivi garantiti (titoli di sezione, nomi di aziende passate). L'utente li scrive nell'editor.
- **Headline** (Anagrafica): stessa logica, opzionale, non tentata.
- **Foto profilo**: estrazione immagini embedded dal PDF fuori scope dell'MVP dell'import; appartiene al ticket 09.
- **Altri campi Anagrafica opzionali** (data/luogo di nascita, nazionalità, ecc.): pattern non affidabili, non tentati.

### Item grouping in Esperienze / Formazione

Per un blocco riconosciuto come "Esperienze" (o "Formazione"), delimitare i singoli item usando **cascata di strategie**:

1. **Split per data**: cerca tutte le date nel blocco (regex successiva); ogni data ancora un item; il testo tra due date consecutive appartiene allo stesso item.
2. Se **nessuna data** viene trovata → fallback **split per riga vuota**.
3. Se **anche il fallback fallisce** (blocco monolitico senza righe vuote) → **rinunciamo al parsing strutturato**: l'intero blocco diventa una sezione custom con il titolo originale (es. "Esperienze") e contenuto raw come Markdown. L'utente cannibalizza a mano.

### Estrazione campi dentro un item

Per un item ben delimitato di **Esperienze** o **Formazione**:

- **Date** → estratte via regex (vedi sotto); riempiamo `dataInizio`, `dataFine`, `current: true` se rileviamo marker "in corso".
- **Descrizione** → riempita con **l'intero contenuto raw dell'item** (Markdown), incluse le eventuali righe che contengono ruolo/azienda/titolo/ente.
- **Ruolo**, **azienda** (Esperienze) o **titolo**, **ente** (Formazione) → **lasciati vuoti**. L'utente li ritaglia dai primi caratteri della descrizione nell'editor.

Motivazione: distinguere programmaticamente "questa riga è il ruolo, quella è l'azienda" produce troppi errori (aziende senza suffisso legale come Google/Meta/OpenAI, ordini invertiti tra CV, formati eterogenei). Un campo vuoto è meglio di un campo con contenuto sbagliato.

### Formati di data riconosciuti

| Formato | Esempio |
| --- | --- |
| Nome mese esteso italiano (case-insensitive) | `Gennaio 2020` |
| Nome mese abbreviato italiano (3-4 lettere) | `Gen 2020`, `Set 2018` |
| Nome mese esteso inglese (case-insensitive) | `January 2020` |
| Nome mese abbreviato inglese (3 lettere) | `Jan 2020` |
| Numerico slash | `01/2020`, `1/2020` |
| Numerico trattino | `01-2020` |
| Range temporale | `Gen 2020 – Mag 2024`, `2020-2024`, `Jan 2020 - Present` (accetta `-`, `–`, `—`) |
| **Solo anno** | `2020` — **ammesso solo se dentro un range o accanto a un mese**, non isolato (troppo ambiguo con numeri qualsiasi) |
| Marker "in corso" | `oggi`, `presente`, `attualmente`, `in corso`, `present`, `current`, `ongoing` → `dataFine: null` + `current: true` |

Tutte le date estratte vengono normalizzate a `"YYYY-MM"` per aderire al ticket 03.

### Sezioni NON strutturate dallo schema (cosa succede)

**Sommario, Skill, Lingue, Certificazioni**: se il titolo è riconosciuto → diventa una **sezione custom** con il titolo originale (es. "Skill") e il contenuto raw come Markdown. Le sezioni fisse corrispondenti nello schema restano **vuote**. Motivazione: estrarre struttura da queste sezioni con euristiche on-device senza LLM è troppo fragile (formati eterogenei, tag e livelli CEFR non rilevabili in modo affidabile). L'utente può poi cannibalizzare la custom per riempire i campi fissi strutturati.

Se il titolo **non è riconosciuto** (non è nel dizionario, o non passa isolamento/geometria) → il contenuto finisce in "Da rivedere" come tutto il resto.

### Riepilogo perimetro MVP

**Mappiamo automaticamente**:
- Contatti (email, telefono, link)
- Esperienze e Formazione (delimitazione item + date + descrizione raw)
- Sezioni riconosciute ma non strutturate → sezioni custom col titolo originale

**Lasciamo all'utente**:
- Anagrafica (nome/cognome/headline/altri campi opzionali)
- Ruolo/azienda dentro Esperienze; titolo/ente dentro Formazione
- Foto profilo (deferred al ticket 09)
- Skill/Lingue/Certificazioni strutturati (raw disponibile come custom section se il titolo è riconosciuto)

### Impatti su altri ticket

- **Ticket 06 (stack)**: nessun impatto — nessuna nuova libreria richiesta oltre a `pdfrx`.
- **Ticket 07 (UX editor)**: aspettarsi che l'editor si apra frequentemente con campi obbligatori vuoti (ruolo/azienda/nome) e con sezioni custom "Da rivedere" o "Skill"/"Lingue" ecc. affiancate a quelle fisse. Il ticket 07 deve prevedere la UX per "sezione custom presente ma valorizzabile → contenuto da spostare".
- **Ticket 09 (foto e asset)**: se in v2 volessimo estrarre foto dai PDF, la superficie sarà `pdfrx.pages[i].images` (da validare); l'MVP non tocca il tema.
