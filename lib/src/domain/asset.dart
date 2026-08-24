/// Reference to an asset stored in the CV document's `assets` store, or an
/// inline base64-encoded asset payload (ticket 03).
library;

import 'package:meta/meta.dart';

/// Reference to an asset inside the document's `assets` store.
@immutable
class AssetRef {
  final String assetId;
  const AssetRef(this.assetId);

  @override
  bool operator ==(Object other) =>
      other is AssetRef && other.assetId == assetId;
  @override
  int get hashCode => assetId.hashCode;
}

/// Binary payload stored in the document's `assets` store.
///
/// MVP allows only one asset (Anagrafica.foto), see ticket 09; the shape
/// however is generic to keep future extensions cheap.
@immutable
class Asset {
  final String mimeType;
  final String data; // base64-encoded (no data: prefix, no newlines)

  const Asset({required this.mimeType, required this.data});

  Asset copyWith({String? mimeType, String? data}) => Asset(
    mimeType: mimeType ?? this.mimeType,
    data: data ?? this.data,
  );

  @override
  bool operator ==(Object other) =>
      other is Asset && other.mimeType == mimeType && other.data == data;

  @override
  int get hashCode => Object.hash(mimeType, data);
}
