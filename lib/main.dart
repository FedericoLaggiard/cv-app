/// Entry point for the CV app.
///
/// Wires the dependency graph:
///  - [CvRepository] built by [defaultCvRepository] — [PathProviderCvRepository]
///    on desktop/mobile, [IdbCvRepository] on Web.
///  - [LibraryCubit] provided at the root so it outlives any single screen.
///  - [GoRouter] with two routes: `/` (Library) and `/editor/:id` (stub).
///
/// The repository build is async (needs `path_provider` on desktop/mobile,
/// `getIdbFactory()` on web), so [main] awaits it before calling [runApp].
/// While that future is in flight the UI shows a splash [Scaffold], and any
/// failure lands on an error [Scaffold] with a retry button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'src/repository/cv_repository.dart';
import 'src/repository/cv_repository_factory.dart';
import 'src/ui/library/library_cubit.dart';
import 'src/ui/library/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CvApp());
}

/// Root widget.  Materializes the [CvRepository] via [FutureBuilder] so the
/// splash / error screens are part of the standard widget tree.
class CvApp extends StatefulWidget {
  const CvApp({super.key});

  @override
  State<CvApp> createState() => _CvAppState();
}

class _CvAppState extends State<CvApp> {
  late Future<CvRepository> _repoFuture;

  @override
  void initState() {
    super.initState();
    _repoFuture = defaultCvRepository();
  }

  void _retry() {
    setState(() {
      _repoFuture = defaultCvRepository();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV app',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2B6CB0),
        useMaterial3: true,
      ),
      home: FutureBuilder<CvRepository>(
        future: _repoFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StorageErrorScreen(
              error: snapshot.error!,
              onRetry: _retry,
            );
          }
          final repo = snapshot.data;
          if (repo == null) {
            return const _SplashScreen();
          }
          return _AppRoot(repository: repo);
        },
      ),
    );
  }
}

/// Everything that depends on a live [CvRepository]: the [LibraryCubit] and
/// the [GoRouter].  Kept as a separate widget so the router is built exactly
/// once per repository instance.
class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.repository});

  final CvRepository repository;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final LibraryCubit _cubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _cubit = LibraryCubit(repository: widget.repository);
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => BlocProvider.value(
            value: _cubit,
            child: LibraryScreen(
              onOpenVariant: (id) => ctx.push('/editor/$id'),
            ),
          ),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (ctx, state) {
            final id = state.pathParameters['id']!;
            return _EditorPlaceholder(variantId: id);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cubit.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nested Router inside the outer MaterialApp — keeps the splash /
    // error branches simple while still letting go_router own navigation
    // once the repository is ready.
    return Router.withConfig(config: _router);
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
  const _StorageErrorScreen({required this.error, required this.onRetry});

  final Object error;
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
                'Impossibile inizializzare lo storage:\n$error',
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
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
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
