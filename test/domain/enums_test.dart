import 'package:flutter_test/flutter_test.dart';
import 'package:cv_app/src/domain/enums.dart';

void main() {
  group('SectionKind wire values', () {
    test('are canonical snake_case', () {
      expect(SectionKind.anagrafica.wire, 'anagrafica');
      expect(SectionKind.contatti.wire, 'contatti');
      expect(SectionKind.sommario.wire, 'sommario');
      expect(SectionKind.esperienze.wire, 'esperienze');
      expect(SectionKind.formazione.wire, 'formazione');
      expect(SectionKind.skill.wire, 'skill');
      expect(SectionKind.lingue.wire, 'lingue');
      expect(SectionKind.certificazioni.wire, 'certificazioni');
      expect(SectionKind.custom.wire, 'custom');
    });

    test('roundtrip', () {
      for (final k in SectionKind.values) {
        expect(SectionKind.fromWire(k.wire), k);
      }
    });

    test('rejects unknown', () {
      expect(
        () => SectionKind.fromWire('progetti'),
        throwsA(isA<FormatException>()),
      );
    });

    test('isFixed matches ticket 02', () {
      expect(SectionKind.custom.isFixed, isFalse);
      for (final k in SectionKind.values.where((k) => k != SectionKind.custom)) {
        expect(k.isFixed, isTrue);
      }
    });
  });

  group('LivelloCefr', () {
    test('wire values', () {
      expect(LivelloCefr.a1.wire, 'a1');
      expect(LivelloCefr.madrelingua.wire, 'madrelingua');
    });
    test('roundtrip', () {
      for (final v in LivelloCefr.values) {
        expect(LivelloCefr.fromWire(v.wire), v);
      }
    });
  });

  group('ModalitaLavoro', () {
    test('wire matches spec (in_sede, remoto, ibrido)', () {
      expect(ModalitaLavoro.inSede.wire, 'in_sede');
      expect(ModalitaLavoro.remoto.wire, 'remoto');
      expect(ModalitaLavoro.ibrido.wire, 'ibrido');
    });
  });

  group('TipoContratto', () {
    test('wire matches spec', () {
      expect(TipoContratto.fullTime.wire, 'full_time');
      expect(TipoContratto.partTime.wire, 'part_time');
      expect(TipoContratto.freelance.wire, 'freelance');
      expect(TipoContratto.stage.wire, 'stage');
      expect(TipoContratto.consulenza.wire, 'consulenza');
    });
  });

  group('Genere', () {
    test('wire matches spec', () {
      expect(Genere.femminile.wire, 'femminile');
      expect(Genere.maschile.wire, 'maschile');
      expect(Genere.altro.wire, 'altro');
      expect(Genere.preferiscoNonSpecificare.wire, 'preferisco_non_specificare');
    });
  });

  group('StatoCivile', () {
    test('wire matches spec', () {
      expect(StatoCivile.celibeNubile.wire, 'celibe_nubile');
      expect(StatoCivile.coniugato.wire, 'coniugato_a');
      expect(StatoCivile.divorziato.wire, 'divorziato_a');
      expect(StatoCivile.vedovo.wire, 'vedovo_a');
      expect(StatoCivile.convivente.wire, 'convivente');
    });
  });
}
