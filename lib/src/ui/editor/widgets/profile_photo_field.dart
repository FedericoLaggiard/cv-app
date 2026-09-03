/// `ProfilePhotoField` — widget Anagrafica per caricare/cambiare/rimuovere
/// la foto profilo (ticket 26).
///
/// Assente → placeholder + CTA "Aggiungi foto". Presente → thumbnail
/// circolare + azioni "Cambia"/"Rimuovi". Il file scelto passa da
/// [PhotoNormalizer] prima di risalire al chiamante: reject esplicito per i
/// formati non supportati, resize/encode altrimenti.
///
/// Widget *presentazionale*: non conosce `EditorBloc` né il documento, come
/// `TemplatePicker` (ticket 25). Riceve l'[Asset] corrente e restituisce
/// l'asset normalizzato via [onPhotoSelected] / la rimozione via
/// [onRemove]; il cablaggio sul bloc vive in `AnagraficaForm`. Questo
/// tiene il widget testabile senza bloc, repository o timer.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../../domain/asset.dart';
import '../../../photo/photo_normalizer.dart';

/// Bytes + mime della foto scelta dall'utente, prima della normalizzazione.
@immutable
class PickedPhotoFile {
  final Uint8List bytes;
  final String mimeType;
  const PickedPhotoFile(this.bytes, this.mimeType);
}

/// La fotocamera non è raggiungibile: permesso negato, nessun hardware, o
/// altro errore di piattaforma segnalato da `image_picker`.
///
/// Distinto da [PhotoNormalizationError]: qui non ci sono ancora bytes da
/// normalizzare, il fallimento è del picker stesso.
class CameraUnavailableException implements Exception {
  final String detail;
  const CameraUnavailableException(this.detail);

  @override
  String toString() => 'CameraUnavailableException: $detail';
}

/// Picker di default: file system su tutte le piattaforme (su mobile il
/// picker di sistema espone anche la galleria foto).
///
/// Volutamente [FileType.image] e non una whitelist di estensioni: il
/// ticket 26 (user story 5) vuole che un HEIC *si possa scegliere* e riceva
/// un messaggio esplicito che elenca i formati validi. Con un filtro di
/// estensioni quei file sarebbero invisibili nel dialog e l'utente non
/// capirebbe perché — il rifiuto tipizzato di [PhotoNormalizer] resta il
/// cancello vero.
Future<PickedPhotoFile?> defaultPickPhotoFile() async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  if (files.isEmpty) return null;
  final file = files.first;
  final bytes = await file.readAsBytes();
  // Mime dal nome file quando è riconoscibile, altrimenti magic bytes
  // (ticket 26, "Rilevamento mime"): un file senza estensione che è
  // davvero un JPEG deve passare.
  final byName = photoMimeTypeForFileName(file.name);
  final mimeType = kAcceptedPhotoMimeTypes.contains(byName)
      ? byName
      : (sniffPhotoMimeType(bytes) ?? byName);
  return PickedPhotoFile(bytes, mimeType);
}

/// Nome leggibile dei formati che l'utente può scegliere ma non sono
/// supportati, per dirgli *quale* formato ha scelto invece di sputargli
/// addosso un mime type (ticket 26, user story 5).
const Map<String, String> _formatLabels = {
  'image/heic': 'HEIC',
  'image/heif': 'HEIF',
  'image/gif': 'GIF',
  'image/svg+xml': 'SVG',
  'image/bmp': 'BMP',
  'image/tiff': 'TIFF',
};

/// Scatto diretto (user story 2): `image_picker`, sorgente fotocamera.
///
/// Solo Android/iOS hanno una fotocamera di sistema che `image_picker`
/// raggiunge senza configurazione aggiuntiva — su Web/macOS/Windows/Linux
/// `ImageSource.camera` richiede un `cameraDelegate` custom (vedi
/// [defaultCameraAvailable]), quindi lì il chiamante non deve nemmeno
/// esporre questa funzione all'utente.
Future<PickedPhotoFile?> defaultPickPhotoFromCamera() async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.camera);
  } on PlatformException catch (e) {
    throw CameraUnavailableException(e.message ?? e.code);
  }
  if (file == null) return null; // utente ha annullato lo scatto
  final bytes = await file.readAsBytes();
  final mimeType = file.mimeType ?? photoMimeTypeForFileName(file.name);
  return PickedPhotoFile(bytes, mimeType);
}

/// True quando la piattaforma corrente ha una fotocamera di sistema
/// raggiungibile senza `cameraDelegate` custom (ticket 26, user story 2:
/// "da fotocamera (mobile) o da file system (tutte le piattaforme)").
///
/// `defaultTargetPlatform` invece di `dart:io Platform`: quest'ultimo non
/// compila su Web, mentre `defaultTargetPlatform` è sicuro ovunque e
/// riflette comunque il sistema operativo reale fuori dai test (dove è
/// iniettabile per non dipendere dalla macchina che esegue la suite).
bool defaultCameraAvailable() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class ProfilePhotoField extends StatefulWidget {
  ProfilePhotoField({
    super.key,
    required this.asset,
    required this.onPhotoSelected,
    required this.onRemove,
    this.normalizer = const PhotoNormalizer(),
    this.pickFile = defaultPickPhotoFile,
    this.pickFromCamera = defaultPickPhotoFromCamera,
    bool? cameraAvailable,
  }) : cameraAvailable = cameraAvailable ?? defaultCameraAvailable();

  /// Foto profilo attuale, `null` se assente.
  final Asset? asset;

  /// Chiamata con l'asset JPEG già normalizzato da [normalizer].
  final ValueChanged<Asset> onPhotoSelected;

  final VoidCallback onRemove;

  /// Iniettabili nei test — evitano di dipendere dal platform channel reale
  /// di `file_picker`/`image_picker`.
  final PhotoNormalizer normalizer;
  final Future<PickedPhotoFile?> Function() pickFile;
  final Future<PickedPhotoFile?> Function() pickFromCamera;

  /// Quando `true`, "Aggiungi foto"/"Cambia" apre un bottom sheet con la
  /// scelta fra libreria e scatto diretto (user story 2); quando `false`
  /// va dritto a [pickFile], come su desktop/web dove la fotocamera non è
  /// raggiungibile (vedi [defaultCameraAvailable]). Non è `final` con
  /// default costante perché dipende dalla piattaforma a runtime — da qui
  /// il costruttore non più `const`.
  final bool cameraAvailable;

  @override
  State<ProfilePhotoField> createState() => _ProfilePhotoFieldState();
}

class _ProfilePhotoFieldState extends State<ProfilePhotoField> {
  bool _busy = false;
  String? _error;

  /// Tap su "Aggiungi foto"/"Cambia": senza fotocamera va dritto al file
  /// picker (comportamento invariato su desktop/web); con fotocamera apre
  /// il bottom sheet di scelta sorgente (user story 2).
  Future<void> _handleTap() async {
    if (!widget.cameraAvailable) {
      await _pickAndSet(widget.pickFile);
      return;
    }
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return; // utente ha chiuso il sheet
    await _pickAndSet(
      source == _PhotoSource.camera ? widget.pickFromCamera : widget.pickFile,
    );
  }

  Future<void> _pickAndSet(Future<PickedPhotoFile?> Function() picker) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await picker();
      if (picked == null) return; // utente ha annullato il picker
      final normalized = await widget.normalizer.ingest(
        rawBytes: picked.bytes,
        mimeType: picked.mimeType,
      );
      if (!mounted) return;
      widget.onPhotoSelected(
        Asset(
          mimeType: 'image/jpeg',
          data: base64Encode(normalized.jpegBytes),
        ),
      );
    } on PhotoNormalizationError catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } on CameraUnavailableException catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Fotocamera non disponibile. Controlla i permessi nelle '
            'impostazioni del dispositivo.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(PhotoNormalizationError e) => switch (e) {
    RejectedFormat(:final mimeType) => switch (_formatLabels[mimeType]) {
      final label? => 'Formato $label non supportato. Usa JPG, PNG o WebP.',
      // Estensione sconosciuta e magic bytes non riconosciuti: non abbiamo
      // un nome onesto da dare al formato, meglio tacerlo che stampare
      // `application/octet-stream`.
      null => 'Formato non supportato. Usa JPG, PNG o WebP.',
    },
    UndecodableFile() =>
      'Il file scelto non è un\'immagine leggibile. Prova un altro file.',
    TooLargeAfterRetries() =>
      'Questa foto resta troppo pesante anche dopo la compressione. '
          'Prova una foto meno complessa o già più piccola.',
  };

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Thumbnail(asset: asset),
              const SizedBox(width: 12),
              if (asset == null)
                OutlinedButton.icon(
                  key: const Key('profile_photo_add'),
                  onPressed: _busy ? null : _handleTap,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Aggiungi foto'),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('profile_photo_change'),
                      onPressed: _busy ? null : _handleTap,
                      child: const Text('Cambia'),
                    ),
                    OutlinedButton(
                      key: const Key('profile_photo_remove'),
                      onPressed: _busy ? null : widget.onRemove,
                      child: const Text('Rimuovi'),
                    ),
                  ],
                ),
              // Testo invece di un `CircularProgressIndicator`: uno spinner
              // indeterminato anima all'infinito e farebbe scadere in
              // timeout ogni `pumpAndSettle` su un albero che lo contiene.
              if (_busy) ...[
                const SizedBox(width: 12),
                const Text(
                  'Elaboro la foto…',
                  key: Key('profile_photo_busy'),
                ),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                key: const Key('profile_photo_error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.asset});

  final Asset? asset;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final current = asset;
    if (current == null) {
      return CircleAvatar(
        key: const Key('profile_photo_placeholder'),
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_outline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final bytes = decodePhotoBase64(current.data);
    if (bytes == null) {
      return CircleAvatar(
        key: const Key('profile_photo_broken'),
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
    }
    return CircleAvatar(
      key: const Key('profile_photo_thumbnail'),
      radius: size / 2,
      backgroundImage: MemoryImage(bytes),
    );
  }
}

enum _PhotoSource { gallery, camera }

/// Bottom sheet "libreria o fotocamera" (user story 2), mostrato solo
/// quando [ProfilePhotoField.cameraAvailable] è vero.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('profile_photo_source_gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli dalla libreria'),
            onTap: () => Navigator.of(context).pop(_PhotoSource.gallery),
          ),
          ListTile(
            key: const Key('profile_photo_source_camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Scatta una foto'),
            onTap: () => Navigator.of(context).pop(_PhotoSource.camera),
          ),
        ],
      ),
    );
  }
}
