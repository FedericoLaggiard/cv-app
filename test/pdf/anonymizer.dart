/// Deterministic, shape-preserving anonymization for the fixture-capture
/// harness (ticket 50 — see `integration_test/capture_fixtures_test.dart`).
///
/// Automatically anonymizes the PII shapes the import heuristics themselves
/// look for: email, phone, LinkedIn/GitHub profile URLs. **Free-text PII —
/// names, headlines, addresses — is not auto-detected here**: reliably
/// telling "Anna Bianchi" (a name to redact) from "Senior Backend Engineer"
/// (a role to keep) needs more than regex, so whoever runs the capture must
/// redact those by hand in the frozen JSON before committing (see the
/// harness's top doc-comment for the checklist).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

final RegExp emailRe = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
);
final RegExp phoneRe = RegExp(
  r'(?<!\w)(\+\d{1,3}[ \-.]?)?(\(?\d{2,4}\)?[ \-.]?)?\d{3,4}[ \-.]?\d{3,4}(?!\w)',
);
final RegExp linkedinRe = RegExp(
  r'(?:https?://)?(?:www\.)?linkedin\.com/in/[A-Za-z0-9_-]+/?',
  caseSensitive: false,
);
final RegExp githubRe = RegExp(
  r'(?:https?://)?(?:www\.)?github\.com/[A-Za-z0-9_-]+/?',
  caseSensitive: false,
);

/// Persists `original -> anonymized` substitutions across capture runs, so
/// re-running the harness on the same PDF (or hand-authoring a golden
/// against an already-frozen fixture) stays consistent. Gitignored — see
/// `.gitignore` — because it's the key to un-anonymizing the fixtures.
class AnonymizationMap {
  final File file;
  final Map<String, String> _entries;

  AnonymizationMap._(this.file, this._entries);

  factory AnonymizationMap.load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return AnonymizationMap._(file, {});
    }
    final decoded = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, Object?>();
    return AnonymizationMap._(
      file,
      decoded.map((k, v) => MapEntry(k, v as String)),
    );
  }

  void save() {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(_entries)}\n',
    );
  }

  String anonymize(String original, String Function() generate) =>
      _entries.putIfAbsent(original, generate);
}

final Random _random = Random(1337);

String _randomAlpha(int length) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  return List.generate(
    length,
    (_) => alphabet[_random.nextInt(alphabet.length)],
  ).join();
}

String _anonymizeEmail(String email, AnonymizationMap map) =>
    map.anonymize(email, () {
      final at = email.indexOf('@');
      if (at == -1) return email;
      final local = email.substring(0, at);
      final domain = email.substring(at + 1);
      final dot = domain.lastIndexOf('.');
      final tld = dot == -1 ? '.com' : domain.substring(dot);
      return '${_randomAlpha(local.isEmpty ? 6 : local.length)}@example$tld';
    });

String _anonymizePhone(String phone, AnonymizationMap map) => map.anonymize(
  phone,
  () => phone.replaceAllMapped(
    RegExp(r'\d'),
    (_) => _random.nextInt(10).toString(),
  ),
);

String _anonymizeProfileUrl(String url, AnonymizationMap map) =>
    map.anonymize(url, () {
      final username = url.split('/').where((s) => s.isNotEmpty).last;
      return url.replaceFirst(
        username,
        _randomAlpha(username.length.clamp(4, 12)),
      );
    });

/// Applies automatic shape-preserving anonymization to one line of
/// extracted text — email, phone, LinkedIn/GitHub URLs only. Everything
/// else passes through unchanged (see this file's top doc-comment).
String anonymizeLine(String line, AnonymizationMap map) {
  var result = line;
  for (final m in emailRe.allMatches(line)) {
    result = result.replaceAll(m.group(0)!, _anonymizeEmail(m.group(0)!, map));
  }
  for (final m in linkedinRe.allMatches(line)) {
    result = result.replaceAll(
      m.group(0)!,
      _anonymizeProfileUrl(m.group(0)!, map),
    );
  }
  for (final m in githubRe.allMatches(line)) {
    result = result.replaceAll(
      m.group(0)!,
      _anonymizeProfileUrl(m.group(0)!, map),
    );
  }
  for (final m in phoneRe.allMatches(line)) {
    final candidate = m.group(0)!.trim();
    if (candidate.isEmpty) continue;
    final digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
    if (digitCount >= 7 && digitCount <= 15) {
      result = result.replaceAll(candidate, _anonymizePhone(candidate, map));
    }
  }
  return result;
}
