/// Widget tests for [runPdfImportFlow] (ticket 28): picker → outcome
/// handling → variant creation, with a fake picker and a fake [PdfImporter]
/// so no real `pdfrx`/PDFium module is involved (see `pdf_importer.dart`'s
/// doc comment on why that can't run under `flutter test`).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:cv_app/src/domain/cv_document.dart';
import 'package:cv_app/src/domain/cv_section.dart';
import 'package:cv_app/src/pdf/import_proposal_report.dart';
import 'package:cv_app/src/pdf/pdf_importer.dart';
import 'package:cv_app/src/repository/in_memory_cv_repository.dart';
import 'package:cv_app/src/ui/library/library_cubit.dart';
import 'package:cv_app/src/ui/library/pdf_import_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// `pumpAndSettle()` never terminates while the "Analizzo il PDF…" dialog's
/// indeterminate [CircularProgressIndicator] is on screen (it schedules a
/// new frame every tick), so every tap that can trigger that dialog is
/// settled with this bounded pump loop instead: pump until the spinner is
/// gone, then one more pump for whatever dialog/snackbar replaces it.
Future<void> _pumpUntilLoadingGone(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  fail('loading dialog never disappeared');
}

Future<PickedPdfFile?> _pick(String name) async =>
    PickedPdfFile(Uint8List(0), name);

/// Returns [outcomes] in order across successive `import()` calls (or the
/// completer-gated one for the cancel test), tracking the password each
/// call was made with.
class _ScriptedImporter extends PdfImporter {
  _ScriptedImporter(this._outcomes);
  final List<ImportOutcome> _outcomes;
  final List<String?> passwordsSeen = [];
  var _i = 0;

  @override
  Future<ImportOutcome> import(Uint8List bytes, {String? password}) async {
    passwordsSeen.add(password);
    return _outcomes[_i++];
  }
}

/// An importer whose single call never completes until [complete] is
/// invoked — used to test the "Annulla" button on the loading dialog.
class _StallingImporter extends PdfImporter {
  final _completer = Completer<ImportOutcome>();
  void complete(ImportOutcome outcome) => _completer.complete(outcome);

  @override
  Future<ImportOutcome> import(Uint8List bytes, {String? password}) =>
      _completer.future;
}

CvDocument _filledDoc({String email = 'mario@example.com'}) => CvDocument(
  id: 'from-importer',
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2000),
  variantName: 'ignored-by-flow',
  sections: [
    ContattiSection(
      displayTitle: 'Contatti',
      data: ContattiData(email: email),
    ),
  ],
);

Widget _harness({
  required InMemoryCvRepository repo,
  required void Function(String) onOpenVariant,
  required Future<PickedPdfFile?> Function() pickFile,
  required PdfImporter importer,
}) {
  final cubit = LibraryCubit(repository: repo)..load();
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('start_import'),
            onPressed: () => runPdfImportFlow(
              context,
              cubit: cubit,
              onOpenVariant: onOpenVariant,
              pickFile: pickFile,
              importer: importer,
            ),
            child: const Text('start'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('runPdfImportFlow — filled', () {
    testWidgets('opens the review step, and confirming creates the variant', (
      tester,
    ) async {
      final repo = InMemoryCvRepository();
      String? openedId;
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (id) => openedId = id,
          pickFile: () => _pick('Mario Rossi CV.pdf'),
          importer: _ScriptedImporter([
            ImportOutcome.filled(
              _filledDoc(),
              const ImportProposalReport.empty(),
            ),
          ]),
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('Rivedi import'), findsOneWidget);
      expect(openedId, isNull);
      expect(await tester.runAsync(() => repo.watchAll().first), isEmpty);

      await tester.tap(find.byKey(const Key('import_review_confirm')));
      await tester.pumpAndSettle();

      expect(openedId, isNotNull);
      // `testWidgets` runs its body in a fake-async zone: a raw
      // `Stream.first` read never resolves without `runAsync` breaking out
      // to real async.
      final variants = await tester.runAsync(() => repo.watchAll().first);
      expect(variants!.single.variantName, 'Mario Rossi CV');
      final doc = await tester.runAsync(() => repo.watch(openedId!).first);
      expect(
        doc!.sections.whereType<ContattiSection>().single.data.email,
        'mario@example.com',
      );
    });

    testWidgets('cancelling the review step creates no variant', (
      tester,
    ) async {
      final repo = InMemoryCvRepository();
      var opened = false;
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (_) => opened = true,
          pickFile: () => _pick('Mario Rossi CV.pdf'),
          importer: _ScriptedImporter([
            ImportOutcome.filled(
              _filledDoc(),
              const ImportProposalReport.empty(),
            ),
          ]),
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      await tester.tap(find.byKey(const Key('import_review_cancel')));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(await tester.runAsync(() => repo.watchAll().first), isEmpty);
    });
  });

  group('runPdfImportFlow — scanned', () {
    testWidgets('"Crea CV da zero" opens a fresh empty variant', (
      tester,
    ) async {
      final repo = InMemoryCvRepository();
      String? openedId;
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (id) => openedId = id,
          pickFile: () => _pick('scan.pdf'),
          importer: _ScriptedImporter([const ImportOutcome.scanned()]),
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('PDF scansionato'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('pdf_import_scanned_from_scratch')),
      );
      await tester.pumpAndSettle();

      expect(openedId, isNotNull);
      final doc = await tester.runAsync(() => repo.watch(openedId!).first);
      expect(doc!.variantName, 'scan');
      expect(doc.sections, isEmpty);
    });

    testWidgets('"Annulla" leaves the library untouched', (tester) async {
      final repo = InMemoryCvRepository();
      var opened = false;
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (_) => opened = true,
          pickFile: () => _pick('scan.pdf'),
          importer: _ScriptedImporter([const ImportOutcome.scanned()]),
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(await tester.runAsync(() => repo.watchAll().first), isEmpty);
    });
  });

  group('runPdfImportFlow — empty', () {
    testWidgets('shows a snackbar and opens a fresh empty variant', (
      tester,
    ) async {
      final repo = InMemoryCvRepository();
      String? openedId;
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (id) => openedId = id,
          pickFile: () => _pick('blank.pdf'),
          importer: _ScriptedImporter([const ImportOutcome.empty()]),
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('Non ho trovato testo da importare'), findsOneWidget);
      expect(openedId, isNotNull);
      final doc = await tester.runAsync(() => repo.watch(openedId!).first);
      expect(doc!.variantName, 'blank');
    });
  });

  group('runPdfImportFlow — encrypted', () {
    testWidgets('wrong password re-prompts, correct password unlocks', (
      tester,
    ) async {
      final repo = InMemoryCvRepository();
      String? openedId;
      final importer = _ScriptedImporter([
        const ImportOutcome.encrypted(), // first attempt, no password
        const ImportOutcome.encrypted(), // wrong password
        ImportOutcome.filled(
          _filledDoc(),
          const ImportProposalReport.empty(),
        ), // correct password
      ]);
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (id) => openedId = id,
          pickFile: () => _pick('protected.pdf'),
          importer: importer,
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('PDF protetto da password'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('pdf_import_password_field')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('pdf_import_password_submit')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('Password errata, riprova.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('pdf_import_password_field')),
        'correct',
      );
      await tester.tap(find.byKey(const Key('pdf_import_password_submit')));
      await _pumpUntilLoadingGone(tester);

      expect(find.text('Rivedi import'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import_review_confirm')));
      await tester.pumpAndSettle();

      expect(openedId, isNotNull);
      expect(importer.passwordsSeen, [null, 'wrong', 'correct']);
    });
  });

  group('runPdfImportFlow — cancelling the loading dialog', () {
    testWidgets('ignores the eventual outcome', (tester) async {
      final repo = InMemoryCvRepository();
      var opened = false;
      final importer = _StallingImporter();
      await tester.pumpWidget(
        _harness(
          repo: repo,
          onOpenVariant: (_) => opened = true,
          pickFile: () => _pick('slow.pdf'),
          importer: importer,
        ),
      );
      await tester.tap(find.byKey(const Key('start_import')));
      await tester.pump();

      expect(find.text('Analizzo il PDF…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pdf_import_cancel_loading')));
      await tester.pumpAndSettle();

      importer.complete(
        ImportOutcome.filled(_filledDoc(), const ImportProposalReport.empty()),
      );
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(await tester.runAsync(() => repo.watchAll().first), isEmpty);
    });
  });
}
