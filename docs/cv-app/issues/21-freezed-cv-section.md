# Migrazione di `cv_section.dart` a freezed

Type: implementation
Status: open
Depends on: 19
Blocks: 18

## Question

`lib/src/domain/cv_section.dart` contiene `copyWith` e `==` scritti a mano per
`AnagraficaData` e `EsperienzaItem`: quattro funzioni a **complessità
ciclomatica 11**, sopra la soglia di 10 del ticket 18.

## Decisione: freezed, con una premessa onesta

Il progetto ha già `freezed` in dipendenza (ticket 06) ma questi tipi non lo
usano. La migrazione genera `cv_section.freezed.dart`, e i file generati sono
esclusi dall'analisi.

**Va detto chiaramente**: `freezed` **non riduce** la complessità di
`copyWith`/`==` — la genera identica, con gli stessi rami. La sposta in un
file generato che nessuno misura. Il numero non migliora: sparisce dal report.

La migrazione è comunque la scelta giusta, ma **per ragioni sue**, non per la
metrica:

- meno boilerplate da mantenere a mano;
- niente `==` che dimentica un campo quando lo schema cresce — bug reale e
  silenzioso su tipi con molti campi opzionali;
- coerenza con lo stack già scelto nel ticket 06.

La posizione accettata consapevolmente dall'utente è: il codice generato non
viene misurato perché non lo si scrive né lo si mantiene. Ragionevole, purché
sia una scelta e non un effetto collaterale.

## Attenzione

`copy_with_sentinel.dart` esiste per gestire la distinzione fra "campo assente"
e "campo esplicitamente null" nei `copyWith` a mano. `freezed` ha un proprio
meccanismo: la migrazione deve preservare quella semantica, che è già coperta
da test.

## Criteri di accettazione

- [ ] `AnagraficaData` ed `EsperienzaItem` usano `freezed`.
- [ ] Nessuna funzione scritta a mano in `cv_section.dart` supera CC 10.
- [ ] La semantica di `copy_with_sentinel` è preservata; i test relativi sono
      verdi senza modifiche.
- [ ] `*.freezed.dart` e `*.g.dart` sono esclusi dall'analisi del ticket 18.
