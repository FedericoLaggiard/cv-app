/// Desktop/mobile branch of [defaultCvRepository] (ticket 04).
library;

import 'cv_repository.dart';
import 'path_provider_cv_repository.dart';
import 'path_provider_file_system_service.dart';

Future<CvRepository> buildDefaultRepository() async {
  final fs = PathProviderFileSystemService();
  await fs.ensureLibraryDir();
  return PathProviderCvRepository(fs: fs);
}
