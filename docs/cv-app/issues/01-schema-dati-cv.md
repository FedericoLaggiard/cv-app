# Schema dati del CV (sezioni fisse e campi tipizzati)

Type: grilling
Status: closed

## Question

Definire lo **schema fisso ricco** del CV: elenco esatto delle sezioni predefinite e, per ciascuna, i campi tipizzati che l'editor gestirà con form guidati.

Punti da chiudere:
- Elenco definitivo delle sezioni fisse (candidati: Anagrafica, Contatti, Sommario/Profilo, Esperienze, Formazione, Skill, Lingue, Progetti, Certificazioni, Pubblicazioni, Volontariato — quali dentro e quali no).
- Per ogni sezione: nome campo, tipo (stringa, testo lungo, data / periodo, enum, lista, url, email, telefono, tag), obbligatorio/opzionale, cardinalità (uno o lista).
- Come si rappresentano i periodi (data inizio + data fine + "in corso").
- Come si rappresentano le skill (lista piatta? categorizzata? con livello?).
- Ordine di default delle sezioni nel CV.

Output atteso: una tabella / lista strutturata pronta da diventare tipi Dart nella spec.

## Risoluzione

### Sezioni fisse dello schema (in ordine di default)

1. Anagrafica
2. Contatti
3. Sommario / Profilo
4. Esperienze lavorative
5. Formazione
6. Skill
7. Lingue
8. Certificazioni

Sezioni escluse dallo schema fisso (l'utente le può aggiungere via sezioni custom se serve): Progetti, Pubblicazioni, Volontariato.

Anagrafica e Contatti sono **sezioni separate e indipendenti**: un template può renderizzarle in punti diversi (es. contatti in sidebar, anagrafica in testa).

### Decisione trasversale: Rich text = Markdown

Tutti i campi di testo lungo (Sommario, Descrizione Esperienze/Formazione/Certificazioni, Note Lingue, campo principale Skill) usano **Markdown**. Sottoinsieme atteso: bold, italic, liste, link.

Conseguenze (non risolte qui, restano in carico ai ticket relativi):
- Ticket 06 (stack): serve una libreria editor Markdown per Flutter.
- Ticket 08 (template PDF): i template devono renderizzare il subset Markdown scelto.
- Ticket 05 (import PDF): l'import produce Markdown (o testo piatto convertito in Markdown banale).

### Campi per sezione

Legenda: **obbl** = obbligatorio; **opz** = opzionale. Cardinalità "lista" = più voci per sezione; altrimenti singola.

#### 1. Anagrafica (singola)

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Nome | stringa | obbl |
| Cognome | stringa | obbl |
| Data di nascita | data | opz |
| Luogo di nascita | stringa | opz |
| Nazionalità | stringa | opz |
| Genere | enum | opz |
| Stato civile | enum | opz |
| Codice fiscale | stringa | opz |
| Foto profilo | asset (storage definito da ticket 09) | opz |
| Titolo professionale / headline | stringa | opz |

#### 2. Contatti (singola)

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Email | email | opz |
| Telefono | stringa (singolo) | opz |
| Città di residenza | stringa | opz |
| Indirizzo completo | stringa | opz |
| Link | lista di `{label: stringa, url: url, icon?: stringa}` | opz |

Niente campi dedicati per LinkedIn/GitHub/sito personale: tutto va nella lista generica `Link`.

#### 3. Sommario / Profilo (singola)

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Testo | Markdown (testo lungo) | opz |

Nessun campo "titolo": l'headline sta già in Anagrafica.

#### 4. Esperienze lavorative (lista)

Per singola voce:

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Ruolo | stringa | obbl |
| Azienda | stringa | obbl |
| Luogo | stringa | opz |
| Modalità | enum (in sede / remoto / ibrido) | opz |
| Tipo contratto | enum (full-time / part-time / freelance / stage / consulenza) | opz |
| Data inizio | mese+anno | obbl |
| Data fine | mese+anno oppure flag "in corso" | opz |
| Descrizione | Markdown | opz |

Granularità date: **mese+anno**. Il flag "in corso" sostituisce la data fine.

#### 5. Formazione (lista)

Per singola voce:

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Titolo di studio / Corso | stringa | obbl |
| Istituto | stringa | opz |
| Luogo | stringa | opz |
| Data inizio | mese+anno | opz |
| Data fine | mese+anno oppure flag "in corso" | opz |
| Voto / Valutazione | stringa libera | opz |
| Descrizione | Markdown | opz |

Nessun campo `livello` (enum triennale/magistrale/…): non serve.

#### 6. Skill (singola)

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Contenuto | Markdown | opz |
| Tag | lista piatta di stringhe libere | opz |

Nessuna categoria, nessun livello. I tag sono liberi (l'utente digita quello che vuole); i template possono renderizzarli come chip/pill.

#### 7. Lingue (lista)

Per singola voce:

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Lingua | stringa libera | obbl |
| Livello | enum CEFR: A1 / A2 / B1 / B2 / C1 / C2 / Madrelingua | obbl |
| Certificazione | stringa libera (es. "IELTS 7.5") | opz |
| Note | Markdown breve | opz |

UX editor: mostrare descrizione di cosa significa ogni livello CEFR (tooltip o helper text).

#### 8. Certificazioni (lista)

Per singola voce:

| Campo | Tipo | Obbl/Opz |
|---|---|---|
| Nome | stringa | obbl |
| Ente emittente | stringa | obbl |
| Data conseguimento | mese+anno | opz |
| Data scadenza | mese+anno | opz |
| Codice / ID credenziale | stringa | opz |
| URL di verifica | url | opz |
| Descrizione / Note | Markdown | opz |
