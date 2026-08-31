# Mutation testing notturno a costo zero — GitHub Actions e alternative (dati verificati ad agosto 2026)

Contesto: repo privato `FedericoLaggiard/cv-app` (Flutter/Dart), singolo dev su macOS.
Job target: `mutation_test` su `lib/src/domain/`, 719 mutanti, ~90 min per giro, 1 giro/notte.
Vincolo: **costo zero**.

---

## 1. Free tier GitHub Actions oggi

| Piano | Minuti/mese inclusi | Storage artifact/packages | Cache | Repo pubblici |
|---|---|---|---|---|
| Free | 2.000 | 500 MB | 10 GB/repo | **gratis, minuti non conteggiati** |
| Pro | 3.000 | 1 GB | 10 GB/repo | gratis |
| Team | 3.000 | 2 GB | 10 GB/repo | gratis |
| Enterprise Cloud | 50.000 | 50 GB | 10 GB/repo | gratis |

- I minuti inclusi si applicano **solo ai repo privati**: «GitHub Actions usage is free for standard GitHub-hosted runners in public repositories, and for self-hosted runners» — [Billing for GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- Piani e minuti confermati anche su [github.com/pricing](https://github.com/pricing) (Free 2.000 min + 500 MB; Team 3.000 min + 2 GB; Enterprise 50.000 min + 50 GB).
- **Superamento**: se non c'è un metodo di pagamento valido, l'uso viene **bloccato** una volta esaurita la quota; se c'è, l'eccedenza viene **addebitata** alle tariffe sotto ([Billing for GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions)).
- Cache: limite di default **10 GB per repository**, con eviction delle entry non accedute da **oltre 7 giorni**; oltre i 10 GB si paga ([Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)).

## 2. Moltiplicatori / tariffe per runner (repo privati)

| Runner standard | $/minuto | Moltiplicatore vs Linux 2-core |
|---|---|---|
| Linux 2-core x64 (`ubuntu-latest`) | $0,006 | 1× |
| Linux 1-core x64 | $0,002 | 0,33× |
| Windows 2-core x64 | $0,010 | ~1,67× |
| macOS 3-4 core | $0,062 | ~10,3× |

Fonte: [Actions minute multipliers](https://docs.github.com/en/billing/reference/actions-minute-multipliers). Nota: «GitHub rounds the minutes and partial minutes each job uses up to the nearest whole minute»; i minuti inclusi **non** sono spendibili su larger runner, e i larger runner **non sono gratuiti nemmeno sui repo pubblici**.

## 3. Calcolo esplicito: 90 min/notte × 30 notti su `ubuntu-latest`

Consumo = 90 min × 30 = **2.700 minuti/mese** (moltiplicatore Linux = 1×).

**Repo PRIVATO, piano Free (2.000 min):**
- 2.700 − 2.000 = **700 minuti in eccedenza**
- 700 × $0,006 = **$4,20/mese** (~$50/anno), oppure **blocco delle esecuzioni** se non c'è carta registrata.
- → **NON rientra nel free tier.** Il budget si esaurisce intorno al **22° giorno** del mese (2.000/90 = 22,2 run).

**Repo PRIVATO, piano Pro/Team (3.000 min):**
- 2.700 ≤ 3.000 → rientra, ma consuma il **90%** della quota, lasciando 300 min (≈3 run) per tutto il resto della CI. Inoltre Pro/Team **non sono a costo zero** (Team $4/utente/mese su [github.com/pricing](https://github.com/pricing)), quindi violano il vincolo.

**Repo PUBBLICO (qualsiasi piano):**
- 2.700 minuti su runner standard → **$0, senza limite di minuti** ([Billing for GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions)).
- Caveat: sui repo pubblici «scheduled workflows are automatically disabled when no repository activity has occurred in 60 days» ([Disabling and enabling a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows)).

Limiti tecnici compatibili: un job su runner GitHub-hosted può durare fino a **6 ore** e un workflow run fino a 35 giorni ([Limits](https://docs.github.com/en/actions/reference/limits)) — 90 minuti stanno comodamente dentro.

## 4. Setup Flutter SDK nel job

- `subosito/flutter-action` supporta `cache: true` (cache dell'SDK) e `pub-cache: true` (cache delle dipendenze pub), indipendenti tra loro, implementati internamente con `actions/cache@v5` ([README subosito/flutter-action](https://github.com/subosito/flutter-action)).
- **Il tempo di setup tipico non è documentato dalla action né da GitHub**: non lo stimo. Va misurato sul proprio repo alla prima run (il job stampa la durata di ogni step). Qualunque numero circolante su blog non è fonte primaria.
- Limiti cache rilevanti: 10 GB/repo, eviction a 7 giorni di mancato accesso, cache leggibili solo da branch corrente/default/base ([Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)). Una pipeline notturna **giornaliera** tocca la cache ogni notte, quindi non viene mai evictata per inattività.
- Impatto sul budget: il setup si somma ai 90 minuti e viene arrotondato al minuto intero per job.

## 5. Alternative a costo zero — valutazione

| Opzione | Costo reale | Copre 2.700 min/mese? | Rischi / vincoli |
|---|---|---|---|
| **Rendere il repo pubblico** | $0 | Sì, illimitato su runner standard | Codice e storia esposti; cron auto-disabilitato dopo 60 gg di inattività |
| **Self-hosted runner sul proprio Mac** | $0 di Actions (+ elettricità) | Sì, nessun minuto consumato | Il Mac deve essere acceso/sveglio; manutenzione toolchain; **usare solo con repo privati** |
| **GitLab CI free** | $0 fino a 400 min/mese | **No** (servono 2.700) | Oltre quota si paga o si blocca |
| **CircleCI free** | $0 con 30.000 crediti/mese | Parzialmente: ~3.000 min su Docker Medium; **niente macOS** | Margine risicato, nessun runner Apple |
| **launchd locale sul Mac (niente cloud)** | $0 | Sì | Nessun log centralizzato/notifica se non te la costruisci; Mac deve essere acceso |

Dettagli e fonti:
- **Self-hosted runner**: «GitHub Actions usage is free ... for self-hosted runners» — i minuti **non** vengono scalati dal free tier ([Billing for GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions)). Si registra da Settings → Actions → Runners → New self-hosted runner; supporta macOS. Avvertenza ufficiale: «We recommend that you only use self-hosted runners with private repositories», perché i fork di un repo pubblico possono eseguire codice arbitrario sulla tua macchina ([Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)). Nel caso `cv-app` (privato, un solo dev, nessun fork esterno) questo rischio è sostanzialmente nullo. Limite job self-hosted: 5 giorni ([Limits](https://docs.github.com/en/actions/reference/limits)).
- **GitLab**: «Free tier namespaces receive 400 compute minutes per month»; cost factor 1 per Linux x86-64 small, 6 per macOS M1 ([Compute minutes](https://docs.gitlab.com/ee/ci/pipelines/compute_minutes.html)). 2.700 min ≫ 400 → escluso.
- **CircleCI**: piano Free con 30.000 crediti/mese (≈3.000 min su Linux Medium), nessuna resource class macOS ([CircleCI pricing](https://circleci.com/pricing/)).

**Combinazione notevole e a costo zero pieno:** repo **privato** + **self-hosted runner sul Mac**. Si ottiene l'ergonomia di GitHub Actions (workflow YAML, `schedule:` cron, log, badge, notifiche di failure) senza consumare un solo minuto di quota e senza rendere pubblico il codice.

## 6. Vincoli di `mutation_test` e `flutter test` in CI

- **Display**: unit e widget test non richiedono device né display — «a widget test's environment is replaced with an implementation much simpler than a full-blown UI system»; solo gli integration test girano «on a real device or an OS emulator» ([Flutter testing overview](https://docs.flutter.dev/testing/overview)). Se `lib/src/domain/` è testato con unit test puri, **nessun `xvfb`, nessun emulatore, nessun trucco**: basta l'SDK.
- **Parallelismo**: il package `mutation_test` (v1.8.0, pubblicata il 9 febbraio 2026) **non documenta alcuna opzione di parallelismo/threading** ([pub.dev/packages/mutation_test](https://pub.dev/packages/mutation_test)). Non affermo che non esista internamente: non è verificabile dalla documentazione.
- **Riduzione dei mutanti** (leve documentate sulla stessa pagina):
  - integrazione dei **dati di coverage in formato lcov**: vengono eseguiti solo i mutanti su statement coperti (approccio conservativo — esclude solo i mutanti su righe senza hit);
  - **whitelist di sezioni per file** e range di righe;
  - regole custom via XML/regex e `--no-builtin` per disattivare il set built-in;
  - `--exclude-strings` (sperimentale) ed esclusioni globali per commenti/loop;
  - **analisi incrementale su PR via git diff**, per testare solo i file modificati — pensata esattamente per la CI.
- Formati di report utili in CI: `xml`, `md`, **`junit`/xunit** (integrabile con reporter di test), oltre all'HTML di default.

---

## Raccomandazione

**Prima scelta: repo privato + self-hosted runner GitHub Actions sul Mac, workflow con `on: schedule` notturno.**

Perché:
- è l'unica opzione che soddisfa contemporaneamente *costo zero letterale*, *repo privato* e *2.700 min/mese*: i self-hosted runner non consumano quota ([fonte](https://docs.github.com/en/billing/concepts/product-billing/github-actions));
- l'avvertenza di sicurezza di GitHub sui self-hosted runner riguarda i fork di repo **pubblici**: in un repo privato mono-utente non si applica;
- mantieni workflow-as-code, storico delle run, artifact del report HTML e notifiche di fallimento — cose che un `launchd` puro non ti dà senza lavoro extra.

Trade-off da accettare: il Mac deve essere acceso e non addormentato alle ore notturne (`caffeinate`/impostazioni di risparmio energia o schedulazione di risveglio), e la toolchain sul runner la mantieni tu.

**Seconda scelta (se non vuoi tenere il Mac acceso): rendere il repo pubblico** e usare i runner GitHub-hosted, dove i minuti sono gratis e illimitati. Costa zero ma espone codice e storia, e richiede attività sul repo almeno ogni 60 giorni per non farsi disabilitare il cron.

**Da evitare:** restare su repo privato con runner GitHub-hosted (2.700 min ⇒ $4,20/mese sul piano Free, o blocco a metà mese), GitLab free (400 min, un ordine di grandezza sotto) e CircleCI free (margine troppo stretto, niente macOS).

**In ogni scenario, riduci prima il carico:** alimentare `mutation_test` con l'lcov di coverage e usare la modalità incrementale su diff può abbattere i 719 mutanti — 90 minuti sono un problema di costo *e* di feedback loop, e il fix più economico è generare meno mutanti, non comprare più minuti.
