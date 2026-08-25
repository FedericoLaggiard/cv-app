/// Default [CvRepository] wiring per platform (ticket 04).
///
/// The public entry point is [defaultCvRepository]. On desktop/mobile it
/// builds a [PathProviderCvRepository] on top of
/// [PathProviderFileSystemService]; on Web it opens an [IdbCvRepository]
/// against the browser's IndexedDB via `idb_shim`. Conditional imports
/// keep `dart:io` out of the Web bundle and `dart:html` out of the
/// desktop/mobile bundle.
library;

import 'cv_repository.dart';
import 'cv_repository_factory_io.dart'
    if (dart.library.html) 'cv_repository_factory_web.dart' as impl;

/// Returns the concrete [CvRepository] for the current platform.
Future<CvRepository> defaultCvRepository() => impl.buildDefaultRepository();
