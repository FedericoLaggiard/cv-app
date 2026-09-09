/// Measures the PDF-import conversion rate against the frozen corpus
/// (ticket 50 — "Spec M") and, since Slice P (ticket 53), gates on it:
/// single-column fixtures must clear recall >= 85% / precision >= 90%;
/// multi-column fixtures are held only to precision >= 90% — no recall
/// target, per the Slice P Testing Decisions (multi-column reading order is
/// still unstable, ticket 05).
///
/// `fixtures/europass_it_01.*` is a synthetic placeholder authored by hand
/// — clean, idealized data that proves the harness end-to-end, not a real
/// captured extraction; it does not represent the ~4%/~18% recall/precision
/// the Problem Statement estimated by hand on a real Europass PDF.
/// `fixtures/europass_it_02.*` is a real, anonymized extraction and is the
/// actual reference CV the Slice P heuristics were designed against.
library;

import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversion_scoring.dart';
import 'corpus.dart';
import 'fixture_io.dart';
import 'no_lost_lines.dart';

void main() {
  final corpus = loadCorpus();

  test('il corpus di fixture non è vuoto', () {
    expect(
      corpus,
      isNotEmpty,
      reason: 'test/pdf/fixtures/ deve contenere almeno una fixture',
    );
  });

  group('tasso di conversione', () {
    for (final entry in corpus) {
      test('${entry.name} (${entry.fixture.layoutFamily.wire})', () {
        final (doc, _) = buildFromPages(entry.fixture.toPages());
        final proposed = flattenDocument(doc);
        final score = scoreConversion(
          expected: entry.golden.fields,
          proposed: proposed,
        );

        // ignore: avoid_print
        print(
          '[conversion-rate] ${entry.name}: '
          'recall=${_fmt(score.recall)} precisione=${_fmt(score.precision)} '
          '(${score.correctCount}/${score.expectedCount} attesi, '
          '${score.proposedCount} proposti)',
        );
        for (final section in score.bySection.keys.toList()..sort()) {
          final s = score.bySection[section]!;
          // ignore: avoid_print
          print(
            '[conversion-rate]   $section: recall=${_fmt(s.recall)} '
            'precisione=${_fmt(s.precision)} '
            '(${s.correctCount}/${s.expectedCount} attesi, ${s.proposedCount} proposti)',
          );
        }

        expect(score.expectedCount, greaterThan(0));
        if (score.recall != null) {
          expect(score.recall, inInclusiveRange(0.0, 1.0));
        }
        expect(score.precision, inInclusiveRange(0.0, 1.0));

        // Slice P gate (ticket 53 Testing Decisions): single-column fixtures
        // must clear recall >= 85% / precision >= 90%; multi-column ones are
        // held only to precision >= 90% (no recall target — ticket 05).
        switch (entry.fixture.layoutFamily) {
          case LayoutFamily.singleColumn:
            expect(
              score.recall,
              greaterThanOrEqualTo(0.85),
              reason:
                  '${entry.name}: recall sotto la soglia single-column (85%)',
            );
            expect(
              score.precision,
              greaterThanOrEqualTo(0.90),
              reason:
                  '${entry.name}: precisione sotto la soglia single-column (90%)',
            );
          case LayoutFamily.multiColumn:
            expect(
              score.precision,
              greaterThanOrEqualTo(0.90),
              reason:
                  '${entry.name}: precisione sotto la soglia multi-column (90%)',
            );
        }
      });
    }
  });

  group('invariante: nessuna riga persa', () {
    for (final entry in corpus) {
      test(entry.name, () {
        final (doc, report) = buildFromPages(entry.fixture.toPages());
        final lost = findLostLines(entry.fixture.allLines, doc, report);
        expect(
          lost,
          isEmpty,
          reason:
              'Righe estratte da ${entry.name} non finite in nessun campo né in "Da rivedere": $lost',
        );
      });
    }
  });
}

String _fmt(double? ratio) =>
    ratio == null ? 'n/d' : '${(ratio * 100).toStringAsFixed(1)}%';
