/// Web branch of [defaultCvRepository] (ticket 04).
library;

import 'package:idb_shim/idb_browser.dart';

import 'cv_repository.dart';
import 'idb_cv_repository.dart';

Future<CvRepository> buildDefaultRepository() async {
  final factory = getIdbFactory();
  if (factory == null) {
    throw StateError(
      'IndexedDB is not available in this browser environment. '
      'CV app requires IndexedDB (see ticket 04).',
    );
  }
  return IdbCvRepository(factory: factory);
}
