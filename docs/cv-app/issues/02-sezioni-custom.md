# Sezioni custom aggiuntive

Type: grilling
Status: closed
Blocked by: 01

## Question

Definire la semantica delle **sezioni custom** che l'utente può aggiungere sopra allo schema fisso.

Punti da chiudere:
- Dove si collocano nel CV: in coda, o in posizione libera (drag & drop)?
- Che struttura interna hanno: solo titolo + testo libero, oppure titolo + lista di voci con campi minimi (titolo voce, sottotitolo, descrizione, date)?
- Sono per-variante o condivise tra varianti dello stesso utente?
- Come si comportano i template hard-coded quando incontrano sezioni sconosciute? (Rendering generico fallback? Ordine? Titoli tradotti?)
- Limiti: numero massimo di sezioni custom? Nomi riservati (per evitare collisioni con quelle fisse)?

Output atteso: descrizione del modello dati per le sezioni custom + regole di rendering nei template.

## Vincoli decisi a monte

- Schema dati fisso e rich text = Markdown definiti in [ticket 01](01-schema-dati-cv.md). Considerare quel documento come input.

## Risoluzione

**Struttura interna**: una sezione custom è **titolo + un unico blob Markdown**. Nessun sotto-schema, nessuna lista di voci, nessuno "stampo" da scegliere.

**Posizionamento**: **ordine globale libero**. Le sezioni custom possono essere collocate in qualsiasi punto della sequenza — anche in mezzo alle fisse. Il modello dati del CV mantiene un **ordine esplicito** dell'intera lista di sezioni (fisse + custom), che i template rispettano; nessun template ha un ordinamento hard-coded proprio.

**Scope**: **per-variante**. Ogni file variante contiene le proprie sezioni custom; niente "libreria di sezioni" a livello utente, coerente col fatto che le varianti sono file indipendenti senza backend.

**Rendering nei template**: **stesso block-renderer usato per le sezioni fisse a blob** (in primis "Sommario"). Il template espone una funzione "renderisci sezione a blob (titolo, markdown)" riusata identicamente per Sommario e per ogni sezione custom. Le sezioni strutturate (Esperienze, Formazione, Skill, Lingue, Certificazioni, Anagrafica, Contatti) hanno invece renderer dedicati per `kind`.

**Limiti**: **nessun limite** al numero di sezioni custom per variante.

**Unicità nomi**: i **displayTitle** di tutte le sezioni presenti in una variante (fisse rinominate + custom) devono essere **univoci**. L'editor rifiuta di creare una sezione custom con un titolo già in uso, e rifiuta di rinominare una sezione (fissa o custom) in un titolo già in uso.

**Identità sezione ≠ titolo (nuova regola strutturale emersa qui)**:
- Ogni sezione ha un `kind` **stabile e immutabile**. I `kind` delle fisse sono un enum chiuso (`personal`, `contacts`, `summary`, `experience`, `education`, `skills`, `languages`, `certifications`). Le custom hanno `kind: "custom"`.
- Ogni sezione ha un `displayTitle` **modificabile** dall'utente — è la stringa mostrata nel CV renderizzato. Il `kind` decide *quale renderer* usa il template; il `displayTitle` decide *cosa scrive come intestazione*.
- Le sezioni fisse hanno `displayTitle` di default localizzato (es. `experience` → "Esperienze"), ma l'utente può cambiarlo per variante.

**Rimozione sezioni fisse**: l'utente può **rimuovere qualsiasi sezione fissa** da una variante senza limiti (nessuna sezione fissa è obbligatoriamente presente). Rimozione = la sezione non compare né nell'editor né nell'export di quella variante; il suo `kind` resta disponibile per essere ri-aggiunto in seguito.

**Impatti sui ticket a valle** (non aprire ticket nuovi — ricadono negli aperti):
- **Formato file (03)**: il JSON deve serializzare la lista ordinata di sezioni con `{kind, displayTitle, ...payload_kind_specifico}` per le fisse e `{kind: "custom", displayTitle, body: markdown}` per le custom; l'assenza di una fissa è semplicemente "non presente nella lista".
- **Template (08)**: ogni template dichiara un renderer per ciascun `kind` fisso strutturato e riusa un unico "block renderer Markdown" per `summary` e `custom`.
- **UX editor (07)**: l'editor deve permettere rinomina di ogni sezione, rimozione delle fisse, aggiunta di custom con validazione unicità nomi, riordino globale drag & drop.
