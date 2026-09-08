/// Web-only graceful degrade for PDF import (ticket 28, per ticket 10's
/// "piano B"): if `pdfrx`'s WASM module can't initialize on the current
/// browser/target, the "Da PDF esistente" entry point disables itself with
/// an explicit tooltip instead of crashing on first use.
///
/// A no-op everywhere except Web — native platforms always report available
/// without touching `pdfrx` (native PDFium loading failures surface per-file
/// instead, e.g. as an [ImportOutcome] the importer can't produce, which is
/// out of scope here: this only gates the *module* being usable at all).
library;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// Caches whether `pdfrx` is usable on this run, so the check only ever
/// runs once per app session.
class ImportAvailability {
  ImportAvailability._();
  static final ImportAvailability instance = ImportAvailability._();

  bool? _available;

  /// True if PDF import can be offered on this platform/target. Always
  /// `true` off Web. On Web, lazily probes `pdfrx`'s WASM init once and
  /// caches the result for the rest of the session.
  Future<bool> isAvailable() async {
    if (!kIsWeb) return true;
    final cached = _available;
    if (cached != null) return cached;
    try {
      await pdfrxFlutterInitialize();
      final doc = await PdfDocument.createNew(sourceName: 'availability_probe');
      await doc.dispose();
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Synchronous best-effort read of the last known result — `null` while
  /// [isAvailable] hasn't resolved yet (native platforms: never null, always
  /// `true`).
  bool? get cachedAvailable => kIsWeb ? _available : true;

  @visibleForTesting
  void debugReset() => _available = null;

  @visibleForTesting
  void debugOverride(bool value) => _available = value;
}
