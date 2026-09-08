/// Serialization for frozen PDF-extraction fixtures (ticket 50).
///
/// A [PdfFixture] is what `integration_test/capture_fixtures_test.dart`
/// writes to `test/pdf/fixtures/<nome>.json` once, by hand, on macOS: the
/// anonymized line/height output of a real PDF extraction. `dart test`
/// reads it back and feeds it to `buildFromPages` via [PdfFixture.toPages]
/// — no `pdfrx`/PDFium involved.
library;

import 'dart:convert';

import 'package:cv_app/src/pdf/pdf_import_heuristics.dart';

/// The structural family of a CV in the corpus (ticket 50 — see
/// "Famiglia di layout" in CONTEXT.md).
enum LayoutFamily {
  singleColumn('single_column'),
  multiColumn('multi_column');

  const LayoutFamily(this.wire);
  final String wire;

  static LayoutFamily fromWire(String value) {
    for (final f in LayoutFamily.values) {
      if (f.wire == value) return f;
    }
    throw FormatException('Unknown layout family: $value');
  }
}

/// One extracted line: text plus the height used as the heading-detection
/// proxy (mirrors [PdfCharRect], deliberately — see ticket 50 fixture
/// format note).
class FixtureLine {
  final String text;
  final double height;

  const FixtureLine({required this.text, required this.height});

  Map<String, Object?> toJson() => {'text': text, 'height': height};

  factory FixtureLine.fromJson(Map<String, Object?> json) => FixtureLine(
    text: json['text'] as String,
    height: (json['height'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is FixtureLine && other.text == text && other.height == height;

  @override
  int get hashCode => Object.hash(text, height);
}

class FixturePage {
  final int pageIndex;
  final List<FixtureLine> lines;

  const FixturePage({required this.pageIndex, required this.lines});

  Map<String, Object?> toJson() => {
    'pageIndex': pageIndex,
    'lines': [for (final l in lines) l.toJson()],
  };

  factory FixturePage.fromJson(Map<String, Object?> json) => FixturePage(
    pageIndex: json['pageIndex'] as int,
    lines: [
      for (final l in json['lines'] as List)
        FixtureLine.fromJson((l as Map).cast<String, Object?>()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is FixturePage &&
      other.pageIndex == pageIndex &&
      other.lines.length == lines.length &&
      _listEq(other.lines, lines);

  @override
  int get hashCode => Object.hash(pageIndex, Object.hashAll(lines));
}

/// A frozen extraction capture for one CV of the corpus.
class PdfFixture {
  final LayoutFamily layoutFamily;
  final List<FixturePage> pages;

  const PdfFixture({required this.layoutFamily, required this.pages});

  Map<String, Object?> toJson() => {
    'layoutFamily': layoutFamily.wire,
    'pages': [for (final p in pages) p.toJson()],
  };

  factory PdfFixture.fromJson(Map<String, Object?> json) => PdfFixture(
    layoutFamily: LayoutFamily.fromWire(json['layoutFamily'] as String),
    pages: [
      for (final p in json['pages'] as List)
        FixturePage.fromJson((p as Map).cast<String, Object?>()),
    ],
  );

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  factory PdfFixture.decode(String source) =>
      PdfFixture.fromJson((jsonDecode(source) as Map).cast<String, Object?>());

  /// Converts to the shape `buildFromPages` consumes: one [PdfCharRect] per
  /// line, `text` holding the whole line and `height` doubling as the
  /// heading-detection proxy (see [PdfPageText.plainText] doc).
  List<PdfPageText> toPages() => [
    for (final page in pages)
      PdfPageText(
        pageIndex: page.pageIndex,
        chars: [
          for (final line in page.lines)
            PdfCharRect(
              text: line.text,
              x: 0,
              y: 0,
              width: line.text.length.toDouble(),
              height: line.height,
            ),
        ],
      ),
  ];

  /// Every non-empty line across all pages, trimmed, in reading order —
  /// used by the no-lost-lines invariant test.
  List<String> get allLines => [
    for (final page in pages)
      for (final line in page.lines)
        if (line.text.trim().isNotEmpty) line.text.trim(),
  ];

  @override
  bool operator ==(Object other) =>
      other is PdfFixture &&
      other.layoutFamily == layoutFamily &&
      other.pages.length == pages.length &&
      _listEq(other.pages, pages);

  @override
  int get hashCode => Object.hash(layoutFamily, Object.hashAll(pages));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
