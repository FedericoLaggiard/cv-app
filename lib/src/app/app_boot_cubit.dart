/// App-boot state machine.
///
/// Materializes the platform-specific [CvRepository] via
/// [defaultCvRepository] and exposes its lifecycle as a [Cubit] so the
/// root widget can stay stateless.  Three post-init states: [AppBootReady]
/// carries the repository, [AppBootError] carries a human-readable reason
/// plus a [boot] retry, [AppBootLoading] is the transient in-flight state.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/cv_repository.dart';
import '../repository/cv_repository_factory.dart';

sealed class AppBootState {
  const AppBootState();
}

class AppBootInitial extends AppBootState {
  const AppBootInitial();
}

class AppBootLoading extends AppBootState {
  const AppBootLoading();
}

class AppBootReady extends AppBootState {
  final CvRepository repository;
  const AppBootReady(this.repository);
}

class AppBootError extends AppBootState {
  final String message;
  const AppBootError(this.message);
}

class AppBootCubit extends Cubit<AppBootState> {
  final Future<CvRepository> Function() _build;

  AppBootCubit({Future<CvRepository> Function()? buildRepository})
      : _build = buildRepository ?? defaultCvRepository,
        super(const AppBootInitial());

  /// Kicks off (or restarts) the storage build.  Emits [AppBootLoading],
  /// then either [AppBootReady] or [AppBootError].
  Future<void> boot() async {
    emit(const AppBootLoading());
    try {
      final repo = await _build();
      emit(AppBootReady(repo));
    } catch (e) {
      emit(AppBootError(e.toString()));
    }
  }
}
