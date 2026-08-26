/// Entry point for the CV app.
///
/// Wires the dependency graph fully stateless:
///  - [AppBootCubit] materializes the platform-specific [CvRepository]
///    ([PathProviderCvRepository] on desktop/mobile, [IdbCvRepository] on Web).
///  - Once ready, [LibraryCubit] is provided via [BlocProvider.create]
///    (and calls `load()` on init).
///  - [GoRouter] is provided via [RepositoryProvider.create] with two
///    routes: `/` (Library) and `/editor/:id` (stub).
///
/// While storage init is in flight the UI shows a splash [Scaffold]; any
/// failure lands on an error [Scaffold] with a retry button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'src/app/app_boot_cubit.dart';
import 'src/repository/cv_repository.dart';
import 'src/ui/library/library_cubit.dart';
import 'src/ui/library/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CvApp());
}

class CvApp extends StatelessWidget {
  const CvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppBootCubit>(
      create: (_) => AppBootCubit()..boot(),
      child: MaterialApp(
        title: 'CV app',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2B6CB0),
          useMaterial3: true,
        ),
        home: const _BootGate(),
      ),
    );
  }
}

/// Splits the boot state machine into three screens: splash, error, ready.
class _BootGate extends StatelessWidget {
  const _BootGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBootCubit, AppBootState>(
      builder: (context, state) => switch (state) {
        AppBootInitial() || AppBootLoading() => const _SplashScreen(),
        AppBootError(:final message) => _StorageErrorScreen(
          message: message,
          onRetry: () => context.read<AppBootCubit>().boot(),
        ),
        AppBootReady(:final repository) => _AppRoot(repository: repository),
      },
    );
  }
}

/// Everything that depends on a live [CvRepository]: the [LibraryCubit] and
/// the [GoRouter], each provided via flutter_bloc's DI so the tree stays
/// stateless.  [LibraryCubit.load] runs eagerly via `..load()`.
class _AppRoot extends StatelessWidget {
  const _AppRoot({required this.repository});

  final CvRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryCubit>(
      create: (_) => LibraryCubit(repository: repository)..load(),
      child: RepositoryProvider<GoRouter>(
        create: (routerCtx) => _buildRouter(routerCtx.read<LibraryCubit>()),
        child: Builder(
          builder: (ctx) => Router.withConfig(config: ctx.read<GoRouter>()),
        ),
      ),
    );
  }

  static GoRouter _buildRouter(LibraryCubit cubit) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => BlocProvider.value(
            value: cubit,
            child: LibraryScreen(
              onOpenVariant: (id) => ctx.push('/editor/$id'),
            ),
          ),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (_, state) => _EditorPlaceholder(
            variantId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StorageErrorScreen extends StatelessWidget {
  const _StorageErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Impossibile inizializzare lo storage:\n$message',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temporary placeholder for the Editor screen (lands with the editor slice).
class _EditorPlaceholder extends StatelessWidget {
  const _EditorPlaceholder({required this.variantId});

  final String variantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Text(
          'Editor per variante $variantId\n(landing con il prossimo ticket)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
