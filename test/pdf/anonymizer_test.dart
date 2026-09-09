/// Unit tests for the capture-harness anonymizer (ticket 50).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'anonymizer.dart';

void main() {
  late Directory tmp;
  late AnonymizationMap map;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('anonymizer_test');
    map = AnonymizationMap.load('${tmp.path}/map.json');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('anonimizza email preservando lo shape del dominio', () {
    final result = anonymizeLine('Contatto: mario.rossi@example.com', map);
    expect(result, isNot(contains('mario.rossi')));
    expect(result, contains('@example.com'));
    expect(result, startsWith('Contatto: '));
  });

  test('anonimizza il telefono preservando la punteggiatura', () {
    final result = anonymizeLine('Tel: +39 333 1234567', map);
    expect(result, matches(RegExp(r'^Tel: \+\d{2} \d{3} \d{7}$')));
    expect(result, isNot(contains('333 1234567')));
  });

  test('anonimizza username LinkedIn/GitHub lasciando il dominio', () {
    final result = anonymizeLine(
      'linkedin.com/in/mariorossi github.com/mariorossi',
      map,
    );
    expect(result, contains('linkedin.com/in/'));
    expect(result, contains('github.com/'));
    expect(result, isNot(contains('mariorossi')));
  });

  test('è idempotente: la stessa mappa produce la stessa sostituzione', () {
    final first = anonymizeLine('mario.rossi@example.com', map);
    final second = anonymizeLine('mario.rossi@example.com', map);
    expect(first, second);
  });

  test('persiste su file e viene ricaricata identica', () {
    anonymizeLine('mario.rossi@example.com', map);
    map.save();

    final reloaded = AnonymizationMap.load('${tmp.path}/map.json');
    final result = anonymizeLine('mario.rossi@example.com', reloaded);
    expect(result, anonymizeLine('mario.rossi@example.com', map));
  });

  test('testo libero senza PII strutturata passa invariato', () {
    expect(
      anonymizeLine('Sviluppatrice Backend', map),
      'Sviluppatrice Backend',
    );
  });
}
