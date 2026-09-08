/// PDF auto-import seam (ticket 28): encapsulates `pdfrx` extraction, the
/// scanned/encrypted/empty detection from tickets 10/12, and hands off to
/// the pure heuristics module (`pdf_import_heuristics.dart`, ticket 13) to
/// produce a pre-filled [CvDocument].
///
/// Not unit-tested against `pdfrx` itself (declared trust, ticket 05/10):
/// `PdfDocument.openData`'s native PDFium module needs platform native-asset
/// wiring that `flutter test` doesn't provide outside a running app, so
/// [PdfImporter.import] is only exercised manually / via a real device or
/// browser run. The classification logic it delegates to ([classifyOutcome])
/// is pure and covered in `test/pdf/pdf_importer_test.dart`.
library;

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../domain/cv_document.dart';
import 'pdf_import_heuristics.dart' as heuristics;

/// Result of [PdfImporter.import].
sealed class ImportOutcome {
  const ImportOutcome();

  const factory ImportOutcome.filled(CvDocument doc) = FilledOutcome;
  const factory ImportOutcome.scanned() = ScannedOutcome;
  const factory ImportOutcome.encrypted() = EncryptedOutcome;
  const factory ImportOutcome.empty() = EmptyOutcome;
}

class FilledOutcome extends ImportOutcome {
  final CvDocument doc;
  const FilledOutcome(this.doc);
}

class ScannedOutcome extends ImportOutcome {
  const ScannedOutcome();
}

class EncryptedOutcome extends ImportOutcome {
  const EncryptedOutcome();
}

class EmptyOutcome extends ImportOutcome {
  const EmptyOutcome();
}

/// Below this average extracted characters per page, a PDF is treated as a
/// scanned image rather than digital text (ticket 12).
const int _scannedAvgCharsPerPageThreshold = 100;

/// Pure classification of already-extracted page text into an
/// [ImportOutcome] (empty / scanned / filled) — split out from [PdfImporter]
/// so it's testable without a real `pdfrx`/PDFium module (which needs
/// platform native-asset wiring `flutter test` doesn't provide).
ImportOutcome classifyOutcome({
  required int totalChars,
  required int pageCount,
  required List<heuristics.PdfPageText> pages,
}) {
  if (totalChars == 0) {
    return const ImportOutcome.empty();
  }
  final avgCharsPerPage = totalChars / pageCount;
  if (avgCharsPerPage < _scannedAvgCharsPerPageThreshold) {
    return const ImportOutcome.scanned();
  }
  return ImportOutcome.filled(heuristics.buildFromPages(pages));
}

class PdfImporter {
  const PdfImporter();

  Future<ImportOutcome> import(Uint8List bytes, {String? password}) async {
    await pdfrx.pdfrxFlutterInitialize();
    pdfrx.PdfDocument document;
    try {
      document = await pdfrx.PdfDocument.openData(
        bytes,
        passwordProvider: pdfrx.createSimplePasswordProvider(password),
        firstAttemptByEmptyPassword: password == null,
        sourceName: 'pdf_import',
      );
    } on pdfrx.PdfPasswordException {
      return const ImportOutcome.encrypted();
    }

    try {
      final pages = <heuristics.PdfPageText>[];
      var totalChars = 0;
      for (final page in document.pages) {
        final structured = await page.loadStructuredText();
        totalChars += structured.fullText.replaceAll(RegExp(r'\s'), '').length;
        pages.add(_toPageText(page.pageNumber - 1, structured));
      }

      return classifyOutcome(
        totalChars: totalChars,
        pageCount: document.pages.length,
        pages: pages,
      );
    } finally {
      await document.dispose();
    }
  }

  /// Reconstructs line-level [heuristics.PdfPageText] from pdfrx's
  /// word/run-level fragments: splits the page's full text on newlines
  /// (pdfrx's structured-text formatter already inserts them at detected
  /// line breaks) and, for each non-empty line, uses the max fragment
  /// height overlapping that line as the heading-detection proxy.
  heuristics.PdfPageText _toPageText(
    int pageIndex,
    pdfrx.PdfPageText structured,
  ) {
    final chars = <heuristics.PdfCharRect>[];
    var offset = 0;
    for (final rawLine in structured.fullText.split('\n')) {
      final start = offset;
      final end = start + rawLine.length;
      offset = end + 1; // account for the split '\n'

      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      double height = 0;
      final startFragment = structured.getFragmentIndexForTextIndex(start);
      final endFragment = structured.getFragmentIndexForTextIndex(
        end == start ? start : end - 1,
      );
      final loIdx = startFragment < 0 ? 0 : startFragment;
      final hiIdx = endFragment < 0 ? loIdx : endFragment;
      for (var i = loIdx; i <= hiIdx && i < structured.fragments.length; i++) {
        final h = structured.fragments[i].bounds.height;
        if (h > height) height = h;
      }

      chars.add(
        heuristics.PdfCharRect(
          text: trimmed,
          x: 0,
          y: start.toDouble(),
          width: rawLine.length.toDouble(),
          height: height,
        ),
      );
    }
    return heuristics.PdfPageText(pageIndex: pageIndex, chars: chars);
  }
}
