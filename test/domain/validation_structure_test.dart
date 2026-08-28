/// Struttura vs completezza (ticket 07).
///
/// La regola che questi test proteggono: una bozza *incompleta* deve
/// poter essere salvata e riaperta all'infinito, mentre un documento
/// *incoerente* resta rifiutato. Senza questa distinzione l'auto-save
/// dell'editor fallirebbe non appena l'utente aggiunge una sezione
/// vuota, e le modifiche resterebbero solo in memoria.
library;

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/domain/enums.dart';
import 'package:cv_app/src/domain/validation.dart';
import 'package:cv_app/src/domain/year_month.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:flutter_test/flutter_test.dart';

CvDocument _doc({List<CvSection> sections = const []}) => CvDocument(
      id: 'doc-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      variantName: 'v',
      sections: sections,
    );

/// Anagrafica appena aggiunta dall'editor: `_defaultSectionFor` la crea
/// con nome e cognome vuoti.
const _anagraficaVuota = AnagraficaSection(
  displayTitle: 'Anagrafica',
  data: AnagraficaData(nome: '', cognome: ''),
);

void main() {
  group('validateStructure — le bozze incomplete passano', () {
    test('Anagrafica con nome/cognome vuoti', () {
      final doc = _doc(sections: [_anagraficaVuota]);
      expect(() => validateStructure(doc), returnsNormally);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('voce Esperienza appena aggiunta, ruolo e azienda vuoti', () {
      final doc = _doc(sections: [
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'e1',
            ruolo: '',
            azienda: '',
            startDate: YearMonth(2026, 1),
          ),
        ]),
      ]);
      expect(() => validateStructure(doc), returnsNormally);
      expect(() => validate(doc), throwsA(isA<CvValidationException>()));
    });

    test('Lingue e Certificazioni con voci vuote', () {
      final doc = _doc(sections: [
        LingueSection(displayTitle: 'Lingue', items: [
          LinguaItem(id: 'l1', lingua: '', livello: LivelloCefr.b2),
        ]),
        CertificazioniSection(displayTitle: 'Certificazioni', items: [
          CertificazioneItem(id: 'c1', nome: '', ente: ''),
        ]),
      ]);
      expect(() => validateStructure(doc), returnsNormally);
    });
  });

  group('validateStructure — l\'incoerenza resta un errore', () {
    test('displayTitle duplicati', () {
      final doc = _doc(sections: [
        const SommarioSection(displayTitle: 'Profilo', markdown: 'x'),
        CustomSection(id: 'c1', displayTitle: 'profilo', markdown: 'y'),
      ]);
      expect(
          () => validateStructure(doc), throwsA(isA<CvValidationException>()));
    });

    test('due sezioni dello stesso kind fisso', () {
      final doc = _doc(sections: [
        const SommarioSection(displayTitle: 'A', markdown: 'x'),
        const SommarioSection(displayTitle: 'B', markdown: 'y'),
      ]);
      expect(
          () => validateStructure(doc), throwsA(isA<CvValidationException>()));
    });

    test('current=true insieme a endDate', () {
      final doc = _doc(sections: [
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'e1',
            ruolo: 'Dev',
            azienda: 'ACME',
            startDate: YearMonth(2024, 1),
            endDate: YearMonth(2025, 1),
            current: true,
          ),
        ]),
      ]);
      expect(
          () => validateStructure(doc), throwsA(isA<CvValidationException>()));
    });

    test('endDate precedente a startDate', () {
      final doc = _doc(sections: [
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'e1',
            ruolo: 'Dev',
            azienda: 'ACME',
            startDate: YearMonth(2025, 6),
            endDate: YearMonth(2024, 6),
          ),
        ]),
      ]);
      expect(
          () => validateStructure(doc), throwsA(isA<CvValidationException>()));
    });

    test('id di voce vuoto o duplicato', () {
      final vuoto = _doc(sections: [
        LingueSection(displayTitle: 'Lingue', items: [
          LinguaItem(id: '', lingua: 'Italiano', livello: LivelloCefr.c2),
        ]),
      ]);
      expect(() => validateStructure(vuoto),
          throwsA(isA<CvValidationException>()));

      final duplicato = _doc(sections: [
        LingueSection(displayTitle: 'Lingue', items: [
          LinguaItem(id: 'x', lingua: 'Italiano', livello: LivelloCefr.c2),
          LinguaItem(id: 'x', lingua: 'Inglese', livello: LivelloCefr.b2),
        ]),
      ]);
      expect(() => validateStructure(duplicato),
          throwsA(isA<CvValidationException>()));
    });

    test('riferimento ad asset inesistente', () {
      final doc = _doc(sections: [
        AnagraficaSection(
          displayTitle: 'Anagrafica',
          data: AnagraficaData(
            nome: 'Mario',
            cognome: 'Rossi',
            foto: AssetRef('mancante'),
          ),
        ),
      ]);
      expect(
          () => validateStructure(doc), throwsA(isA<CvValidationException>()));
    });
  });

  group('completenessIssues', () {
    test('elenca ogni campo obbligatorio vuoto', () {
      final doc = _doc(sections: [_anagraficaVuota]);
      final issues = completenessIssues(doc);
      expect(issues, hasLength(2));
      expect(issues.any((e) => e.contains('nome')), isTrue);
      expect(issues.any((e) => e.contains('cognome')), isTrue);
    });

    test('cita l\'id della voce per le sezioni-lista', () {
      final doc = _doc(sections: [
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'e1',
            ruolo: '',
            azienda: 'ACME',
            startDate: YearMonth(2026, 1),
          ),
        ]),
      ]);
      final issues = completenessIssues(doc);
      expect(issues, hasLength(1));
      expect(issues.single, contains('e1'));
      expect(issues.single, contains('ruolo'));
    });

    test('vuota per un CV completo', () {
      final doc = _doc(sections: [
        const AnagraficaSection(
          displayTitle: 'Anagrafica',
          data: AnagraficaData(nome: 'Mario', cognome: 'Rossi'),
        ),
        EsperienzeSection(displayTitle: 'Esperienze', items: [
          EsperienzaItem(
            id: 'e1',
            ruolo: 'Dev',
            azienda: 'ACME',
            startDate: YearMonth(2024, 1),
            current: true,
          ),
        ]),
      ]);
      expect(completenessIssues(doc), isEmpty);
      expect(() => validate(doc), returnsNormally);
    });
  });

  group('CvRepository — la bozza incompleta sopravvive al salvataggio', () {
    test('save + rilettura di una variante con campi obbligatori vuoti',
        () async {
      final repo = InMemoryCvRepository();
      final created = await repo.create(initialVariantName: 'Bozza');

      final draft = created.copyWith(sections: [_anagraficaVuota]);
      await expectLater(repo.save(draft), completes);

      final reloaded = await repo.watch(created.id).first;
      expect(reloaded.sections, hasLength(1));
      final anagrafica = reloaded.sections.single as AnagraficaSection;
      expect(anagrafica.data.nome, isEmpty);
    });

    test('save rifiuta comunque un documento incoerente', () async {
      final repo = InMemoryCvRepository();
      final created = await repo.create(initialVariantName: 'Rotta');
      final broken = created.copyWith(sections: [
        const SommarioSection(displayTitle: 'A', markdown: 'x'),
        const SommarioSection(displayTitle: 'B', markdown: 'y'),
      ]);
      await expectLater(
        repo.save(broken),
        throwsA(isA<CvValidationException>()),
      );
    });
  });
}
