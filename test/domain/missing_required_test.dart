/// `analyzeMissingRequired` — la fonte unica dei badge ⚠ dell'editor e
/// degli avvisi di completezza all'export (ticket 07).
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/missing_required.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _doc(List<CvSection> sections) => CvDocument(
      id: 'doc-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      variantName: 'v',
      sections: sections,
    );

EsperienzaItem _esperienza({
  required String id,
  String ruolo = 'Dev',
  String azienda = 'ACME',
}) =>
    EsperienzaItem(
      id: id,
      ruolo: ruolo,
      azienda: azienda,
      startDate: YearMonth(2024, 1),
    );

void main() {
  test('documento senza sezioni → nessun mancante', () {
    final m = analyzeMissingRequired(_doc(const []));
    expect(m.fields, isEmpty);
    expect(m.countForSection(0), 0);
  });

  test('Anagrafica vuota → nome + cognome sulla sezione, senza itemId', () {
    final m = analyzeMissingRequired(_doc(const [
      AnagraficaSection(
        displayTitle: 'Anagrafica',
        data: AnagraficaData(nome: '', cognome: ''),
      ),
    ]));

    expect(m.countForSection(0), 2);
    expect(m.hasFieldMissing(0, field: 'nome'), isTrue);
    expect(m.hasFieldMissing(0, field: 'cognome'), isTrue);
    expect(m.fields.every((f) => f.itemId == null), isTrue);
  });

  test('solo spazi conta come mancante', () {
    final m = analyzeMissingRequired(_doc(const [
      AnagraficaSection(
        displayTitle: 'Anagrafica',
        data: AnagraficaData(nome: '   ', cognome: 'Rossi'),
      ),
    ]));
    expect(m.countForSection(0), 1);
    expect(m.hasFieldMissing(0, field: 'nome'), isTrue);
  });

  test('sezioni senza obbligatori non producono mai badge', () {
    final m = analyzeMissingRequired(_doc([
      ContattiSection(displayTitle: 'Contatti', data: ContattiData()),
      const SommarioSection(displayTitle: 'Sommario', markdown: ''),
      SkillSection(displayTitle: 'Skill', data: SkillData()),
      CustomSection(id: 'c1', displayTitle: 'Extra', markdown: ''),
    ]));
    expect(m.fields, isEmpty);
  });

  test('il conteggio per voce è indipendente da quello per sezione', () {
    final m = analyzeMissingRequired(_doc([
      EsperienzeSection(displayTitle: 'Esperienze', items: [
        _esperienza(id: 'e1', ruolo: '', azienda: ''),
        _esperienza(id: 'e2', ruolo: ''),
        _esperienza(id: 'e3'),
      ]),
    ]));

    expect(m.countForSection(0), 3);
    expect(m.countForItem('e1'), 2);
    expect(m.countForItem('e2'), 1);
    expect(m.countForItem('e3'), 0);
    expect(m.hasFieldMissing(0, itemId: 'e1', field: 'azienda'), isTrue);
    expect(m.hasFieldMissing(0, itemId: 'e2', field: 'azienda'), isFalse);
  });

  test('gli indici di sezione seguono la posizione nel documento', () {
    final m = analyzeMissingRequired(_doc([
      const SommarioSection(displayTitle: 'Sommario', markdown: ''),
      const AnagraficaSection(
        displayTitle: 'Anagrafica',
        data: AnagraficaData(nome: '', cognome: 'Rossi'),
      ),
      FormazioneSection(displayTitle: 'Formazione', items: [
        FormazioneItem(id: 'f1', titolo: ''),
      ]),
    ]));

    expect(m.countForSection(0), 0);
    expect(m.countForSection(1), 1);
    expect(m.countForSection(2), 1);
    expect(m.hasFieldMissing(2, itemId: 'f1', field: 'titolo'), isTrue);
  });

  test('Lingue e Certificazioni: lingua, nome, ente', () {
    final m = analyzeMissingRequired(_doc([
      LingueSection(displayTitle: 'Lingue', items: [
        LinguaItem(id: 'l1', lingua: '', livello: LivelloCefr.b2),
      ]),
      CertificazioniSection(displayTitle: 'Certificazioni', items: [
        CertificazioneItem(id: 'k1', nome: '', ente: ''),
      ]),
    ]));

    expect(m.countForItem('l1'), 1);
    expect(m.countForItem('k1'), 2);
    expect(m.hasFieldMissing(1, itemId: 'k1', field: 'ente'), isTrue);
  });

  test('MissingRequired.empty non riporta nulla', () {
    expect(MissingRequired.empty.fields, isEmpty);
    expect(MissingRequired.empty.countForSection(3), 0);
    expect(MissingRequired.empty.countForItem('x'), 0);
  });
}
