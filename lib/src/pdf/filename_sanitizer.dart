/// Nome-file per l'export PDF: `<variantName sanitizzato>.pdf` (ticket 24).
///
/// Il ticket 24 chiede "lo stesso sanitizer del ticket 04": il repository
/// (ticket 04) non ne aveva mai introdotto uno riutilizzabile, quindi
/// questa è la prima implementazione — pensata perché un domani anche il
/// naming file del repository (import/export `.cvapp`) possa richiamarla.
///
/// Rimuove separatori di path e caratteri riservati Windows/POSIX così il
/// nome è sicuro sia per `file_picker.saveFile()` desktop sia per il nome
/// suggerito dello share sheet mobile/Web.
library;

final RegExp _reservedChars = RegExp(r'[/\\:*?"<>|\x00-\x1F]');
final RegExp _repeatedUnderscore = RegExp(r'_+');
final RegExp _trailingDotsSpaces = RegExp(r'[. ]+$');
final RegExp _leadingUnderscores = RegExp(r'^_+');
final RegExp _trailingUnderscores = RegExp(r'_+$');

const int _maxLength = 120;
const String _fallback = 'cv';

/// Sanitizza [name] per l'uso come nome file (senza estensione).
///
/// Restituisce [_fallback] se, dopo la sanitizzazione, non resta nulla di
/// utilizzabile.
String sanitizeFileName(String name) {
  var result = name.replaceAll(_reservedChars, '_');
  result = result.replaceAll(_trailingDotsSpaces, '');
  result = result.trim();
  result = result.replaceAll(_repeatedUnderscore, '_');
  result = result.replaceAll(_leadingUnderscores, '');
  result = result.replaceAll(_trailingUnderscores, '');
  if (result.length > _maxLength) {
    result = result.substring(0, _maxLength);
    result = result.replaceAll(_trailingUnderscores, '');
  }
  return result.isEmpty ? _fallback : result;
}
