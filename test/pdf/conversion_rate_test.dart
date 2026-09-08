/// Measures the PDF-import conversion rate against the frozen corpus
/// (ticket 50 — "Spec M"). Builds the metric before touching the
/// heuristics: this test does **not** fail on a threshold — it prints
/// recall/precision with a per-section breakdown and records the baseline.
/// The 85/90 gate arrives with Slice P (ticket 53).
///
/// The corpus fixture shipped here (`fixtures/europass_it_01.*.json`) is a
/// synthetic placeholder authored by hand to exercise this harness
/// end-to-end — it is not a real captured extraction. Real corpus capture
/// happens via `integration_test/capture_fixtures_test.dart`, run once by
/// hand on macOS (see that file's doc comment), which this test does not
/// require and does not run in CI.
library;

import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversion_scoring.dart';
import 'corpus.dart';
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
        final doc = buildFromPages(entry.fixture.toPages());
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

        // Non è un gate di qualità (arriva con la Slice P) — solo una
        // verifica che lo scoring produca numeri validi.
        expect(score.expectedCount, greaterThan(0));
        if (score.recall != null) {
          expect(score.recall, inInclusiveRange(0.0, 1.0));
        }
        expect(score.precision, inInclusiveRange(0.0, 1.0));
      });
    }
  });

  group('invariante: nessuna riga persa', () {
    for (final entry in corpus) {
      test(entry.name, () {
        final doc = buildFromPages(entry.fixture.toPages());
        final lost = findLostLines(entry.fixture.allLines, doc);
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
