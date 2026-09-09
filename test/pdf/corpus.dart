/// Loads the frozen fixture/golden corpus from `test/pdf/fixtures/` (ticket
/// 50). Pure `dart:io` — no Flutter needed, run from the repo root as
/// `flutter test`/`dart test` already do.
library;

import 'dart:io';

import 'fixture_io.dart';
import 'golden_io.dart';

class CorpusEntry {
  final String name;
  final PdfFixture fixture;
  final Golden golden;

  const CorpusEntry({
    required this.name,
    required this.fixture,
    required this.golden,
  });
}

/// One entry per `<nome>.json`/`<nome>.golden.json` pair under
/// `test/pdf/fixtures/`. Ignores the gitignored anonymization map and any
/// other dotfile.
List<CorpusEntry> loadCorpus() {
  final dir = Directory('test/pdf/fixtures');
  final entries = <CorpusEntry>[];
  final fixtureFiles =
      dir
          .listSync()
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.json') && !f.path.endsWith('.golden.json'),
          )
          .where((f) => !f.uri.pathSegments.last.startsWith('.'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in fixtureFiles) {
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    final goldenFile = File('${dir.path}/$name.golden.json');
    if (!goldenFile.existsSync()) {
      throw StateError('Fixture $name.json has no matching $name.golden.json');
    }
    entries.add(
      CorpusEntry(
        name: name,
        fixture: PdfFixture.decode(file.readAsStringSync()),
        golden: Golden.decode(goldenFile.readAsStringSync()),
      ),
    );
  }
  return entries;
}
