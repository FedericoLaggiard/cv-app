/// Widget test su `ProfilePhotoField` (ticket 26, Testing Decisions):
/// stato assente → placeholder + CTA; stato presente → thumbnail +
/// Cambia/Rimuovi; rimuovi → chiama l'update; formato rifiutato →
/// messaggio d'errore; con fotocamera disponibile → bottom sheet di scelta
/// sorgente (user story 2).
///
/// Il widget è presentazionale (nessun `EditorBloc`, nessun repository,
/// nessun timer): il test monta solo lui, come `template_picker_test.dart`.
/// Il cablaggio sul bloc è coperto da `editor_bloc_test.dart`
/// (`AnagraficaPhotoSet`). Lo scatto vero non è testato qui — richiede un
/// device reale (verifica manuale, ticket 26); questi test coprono solo il
/// wiring: quale picker viene chiamato e cosa succede se fallisce.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_app/src/domain/asset.dart';
import 'package:cv_app/src/ui/editor/widgets/profile_photo_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _tinyPngBytes() {
  final image = img.Image(width: 8, height: 8, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodePng(image));
}

Asset _existingAsset() => Asset(
  mimeType: 'image/jpeg',
  data: base64Encode(_tinyPngBytes()),
);

Future<PickedPhotoFile?> _neverCalled() =>
    throw StateError('non doveva essere chiamato');

/// Di default `cameraAvailable: false`: replica il flusso a singolo
/// pulsante (desktop/web) su cui erano scritti i test originali, senza
/// dipendere dalla piattaforma host di `flutter test` (che risolve
/// `defaultTargetPlatform` ad Android — vedi `defaultCameraAvailable`).
/// I test sul bottom sheet lo passano esplicitamente a `true`.
Widget _harness({
  Asset? asset,
  required Future<PickedPhotoFile?> Function() pickFile,
  Future<PickedPhotoFile?> Function() pickFromCamera = _neverCalled,
  bool cameraAvailable = false,
  ValueChanged<Asset>? onPhotoSelected,
  VoidCallback? onRemove,
}) => MaterialApp(
  home: Scaffold(
    body: ProfilePhotoField(
      asset: asset,
      pickFile: pickFile,
      pickFromCamera: pickFromCamera,
      cameraAvailable: cameraAvailable,
      onPhotoSelected: onPhotoSelected ?? (_) {},
      onRemove: onRemove ?? () {},
    ),
  ),
);

/// Due pump bastano a far scorrere la catena `pickFile` → `ingest` →
/// callback: sono future senza timer, quindi non serve `pumpAndSettle`
/// (che su un albero con animazioni indeterminate non tornerebbe mai).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('stato assente: placeholder + CTA "Aggiungi foto"', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(pickFile: () async => null));

    expect(find.byKey(const Key('profile_photo_placeholder')), findsOneWidget);
    expect(find.byKey(const Key('profile_photo_add')), findsOneWidget);
    expect(find.text('Aggiungi foto'), findsOneWidget);
    expect(find.byKey(const Key('profile_photo_change')), findsNothing);
    expect(find.byKey(const Key('profile_photo_remove')), findsNothing);
  });

  testWidgets('stato presente: thumbnail + Cambia/Rimuovi', (tester) async {
    await tester.pumpWidget(
      _harness(asset: _existingAsset(), pickFile: () async => null),
    );

    expect(find.byKey(const Key('profile_photo_thumbnail')), findsOneWidget);
    expect(find.byKey(const Key('profile_photo_change')), findsOneWidget);
    expect(find.byKey(const Key('profile_photo_remove')), findsOneWidget);
    expect(find.byKey(const Key('profile_photo_add')), findsNothing);
  });

  testWidgets('file valido → onPhotoSelected con un asset JPEG', (
    tester,
  ) async {
    Asset? selected;
    await tester.pumpWidget(
      _harness(
        pickFile: () async => PickedPhotoFile(_tinyPngBytes(), 'image/png'),
        onPhotoSelected: (a) => selected = a,
      ),
    );

    await tester.tap(find.byKey(const Key('profile_photo_add')));
    await _settle(tester);

    expect(selected, isNotNull);
    expect(selected!.mimeType, 'image/jpeg');
    final bytes = base64Decode(selected!.data);
    // Magic bytes JPEG (marker SOI): il PNG in ingresso è stato convertito.
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);
    expect(find.byKey(const Key('profile_photo_error')), findsNothing);
  });

  testWidgets('Rimuovi chiama onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      _harness(
        asset: _existingAsset(),
        pickFile: () async => null,
        onRemove: () => removed = true,
      ),
    );

    await tester.tap(find.byKey(const Key('profile_photo_remove')));
    await _settle(tester);

    expect(removed, isTrue);
  });

  testWidgets(
    'formato non supportato: messaggio d\'errore, nessuna selezione',
    (tester) async {
      Asset? selected;
      await tester.pumpWidget(
        _harness(
          pickFile: () async => PickedPhotoFile(Uint8List(0), 'image/heic'),
          onPhotoSelected: (a) => selected = a,
        ),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await _settle(tester);

      expect(find.byKey(const Key('profile_photo_error')), findsOneWidget);
      // Il messaggio nomina il formato scelto, non il mime type grezzo.
      expect(
        find.text('Formato HEIC non supportato. Usa JPG, PNG o WebP.'),
        findsOneWidget,
      );
      expect(selected, isNull);
      expect(find.byKey(const Key('profile_photo_add')), findsOneWidget);
    },
  );

  testWidgets(
    'formato ignoto: messaggio generico, nessun mime type in faccia',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pickFile: () async =>
              PickedPhotoFile(Uint8List(0), 'application/octet-stream'),
        ),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await _settle(tester);

      expect(
        find.text('Formato non supportato. Usa JPG, PNG o WebP.'),
        findsOneWidget,
      );
      expect(find.textContaining('octet-stream'), findsNothing);
    },
  );

  testWidgets('picker annullato: nessun errore, nessuna selezione', (
    tester,
  ) async {
    Asset? selected;
    await tester.pumpWidget(
      _harness(pickFile: () async => null, onPhotoSelected: (a) => selected = a),
    );

    await tester.tap(find.byKey(const Key('profile_photo_add')));
    await _settle(tester);

    expect(selected, isNull);
    expect(find.byKey(const Key('profile_photo_error')), findsNothing);
    expect(find.byKey(const Key('profile_photo_add')), findsOneWidget);
  });

  group('cameraAvailable: true — bottom sheet di scelta sorgente', () {
    testWidgets('tap su "Aggiungi foto" apre il bottom sheet, non il picker '
        'direttamente', (tester) async {
      await tester.pumpWidget(
        _harness(cameraAvailable: true, pickFile: _neverCalled),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profile_photo_source_gallery')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_photo_source_camera')),
        findsOneWidget,
      );
      // pickFile non è ancora stato chiamato: se lo fosse, _neverCalled
      // avrebbe fatto fallire il test con lo StateError.
    });

    testWidgets('"Scegli dalla libreria" chiama pickFile', (tester) async {
      Asset? selected;
      await tester.pumpWidget(
        _harness(
          cameraAvailable: true,
          pickFile: () async => PickedPhotoFile(_tinyPngBytes(), 'image/png'),
          pickFromCamera: _neverCalled,
          onPhotoSelected: (a) => selected = a,
        ),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_photo_source_gallery')));
      await tester.pumpAndSettle();
      await _settle(tester);

      expect(selected, isNotNull);
    });

    testWidgets('"Scatta una foto" chiama pickFromCamera', (tester) async {
      Asset? selected;
      await tester.pumpWidget(
        _harness(
          cameraAvailable: true,
          pickFile: _neverCalled,
          pickFromCamera: () async =>
              PickedPhotoFile(_tinyPngBytes(), 'image/png'),
          onPhotoSelected: (a) => selected = a,
        ),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_photo_source_camera')));
      await tester.pumpAndSettle();
      await _settle(tester);

      expect(selected, isNotNull);
    });

    testWidgets('chiudere il sheet senza scegliere non chiama nessun picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          cameraAvailable: true,
          pickFile: _neverCalled,
          pickFromCamera: _neverCalled,
        ),
      );

      await tester.tap(find.byKey(const Key('profile_photo_add')));
      await tester.pumpAndSettle();
      // Tap fuori dal sheet: lo scrim del ModalBottomSheet lo chiude senza
      // selezione, come il tasto indietro.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_photo_error')), findsNothing);
    });

    testWidgets(
      'fotocamera non disponibile (permesso negato): messaggio dedicato',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            cameraAvailable: true,
            pickFile: _neverCalled,
            pickFromCamera: () =>
                throw const CameraUnavailableException('camera_access_denied'),
          ),
        );

        await tester.tap(find.byKey(const Key('profile_photo_add')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('profile_photo_source_camera')),
        );
        await tester.pumpAndSettle();
        await _settle(tester);

        expect(find.byKey(const Key('profile_photo_error')), findsOneWidget);
        expect(
          find.textContaining('Fotocamera non disponibile'),
          findsOneWidget,
        );
      },
    );
  });
}
