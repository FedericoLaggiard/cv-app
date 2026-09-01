import 'package:cv_app/src/pdf/label_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IT ed EN hanno label diverse per tutte le sezioni fisse', () {
    final it = labelsFor(LabelLocale.it);
    final en = labelsFor(LabelLocale.en);
    expect(it.esperienze, 'Esperienze');
    expect(en.esperienze, 'Experience');
    expect(it.formazione, 'Formazione');
    expect(en.formazione, 'Education');
    expect(it.skill, 'Skill');
    expect(en.skill, 'Skills');
    expect(it.lingue, 'Lingue');
    expect(en.lingue, 'Languages');
    expect(it.certificazioni, 'Certificazioni');
    expect(en.certificazioni, 'Certifications');
    expect(it.presente, 'in corso');
    expect(en.presente, 'present');
  });

  test('intlLocale mappa alle locale intl attese', () {
    expect(LabelLocale.it.intlLocale, 'it_IT');
    expect(LabelLocale.en.intlLocale, 'en_US');
  });
}
