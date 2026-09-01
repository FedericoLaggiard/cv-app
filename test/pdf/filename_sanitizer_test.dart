import 'package:cv_app/src/pdf/filename_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeFileName', () {
    test('lascia invariato un nome già sicuro', () {
      expect(sanitizeFileName('Backend Senior IT'), 'Backend Senior IT');
    });

    test('sostituisce i separatori di path con underscore', () {
      expect(sanitizeFileName('a/b\\c'), 'a_b_c');
    });

    test('rimuove i caratteri riservati Windows/POSIX', () {
      expect(sanitizeFileName('a:b*c?d"e<f>g|h'), 'a_b_c_d_e_f_g_h');
    });

    test('rimuove i caratteri di controllo', () {
      expect(sanitizeFileName('a\tb\nc'), 'a_b_c');
    });

    test('rifila gli spazi/punti finali (non validi su Windows)', () {
      expect(sanitizeFileName('nome.  '), 'nome');
    });

    test('collassa gli underscore ripetuti risultanti', () {
      expect(sanitizeFileName('a///b'), 'a_b');
    });

    test('nome vuoto o tutto-invalido produce un fallback', () {
      expect(sanitizeFileName(''), 'cv');
      expect(sanitizeFileName('   '), 'cv');
      expect(sanitizeFileName('///'), 'cv');
    });

    test('tronca a 120 caratteri mantenendo un nome valido', () {
      final long = 'a' * 200;
      final result = sanitizeFileName(long);
      expect(result.length, 120);
    });
  });
}
