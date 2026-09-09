/// Unit tests for the no-lost-lines invariant helper (ticket 50).
library;

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:flutter_test/flutter_test.dart';

import 'no_lost_lines.dart';

CvDocument _doc(List<CvSection> sections) => CvDocument(
  id: '1',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  variantName: '',
  sections: sections,
);

void main() {
  test('una riga presente in "Da rivedere" non è persa', () {
    final doc = _doc([
      CustomSection(
        id: 'c1',
        displayTitle: 'Da rivedere',
        markdown: 'Mario Rossi',
      ),
    ]);
    expect(findLostLines(['Mario Rossi'], doc), isEmpty);
  });

  test('una riga di heading riconosciuta non è persa anche se non compare nel testo', () {
    final doc = _doc([]);
    expect(findLostLines(['Esperienze'], doc), isEmpty);
  });

  test('una riga data non è persa anche se non compare nel testo', () {
    final doc = _doc([]);
    expect(findLostLines(['Gennaio 2020 - Marzo 2022'], doc), isEmpty);
  });

  test('una riga davvero non tracciabile viene segnalata', () {
    final doc = _doc([
      CustomSection(
        id: 'c1',
        displayTitle: 'Da rivedere',
        markdown: 'altro testo',
      ),
    ]);
    expect(findLostLines(['Riga sparita'], doc), ['Riga sparita']);
  });

  test('righe vuote sono ignorate', () {
    final doc = _doc([]);
    expect(findLostLines(['', '   '], doc), isEmpty);
  });
}
