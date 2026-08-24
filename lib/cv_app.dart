/// Public entry point for the `cv_app` package (foundation layer).
///
/// Wraps the domain model + storage abstraction so consumers can import
/// everything they need with a single `package:cv_app/cv_app.dart`.
library;

export 'src/domain/asset.dart';
export 'src/domain/calendar_date.dart';
export 'src/domain/copy_with_sentinel.dart';
export 'src/domain/cv_document.dart';
export 'src/domain/cv_section.dart';
export 'src/domain/enums.dart';
export 'src/domain/json_codec.dart';
export 'src/domain/migrations.dart';
export 'src/domain/validation.dart';
export 'src/domain/year_month.dart';
export 'src/repository/cv_repository.dart';
export 'src/repository/in_memory_cv_repository.dart';
