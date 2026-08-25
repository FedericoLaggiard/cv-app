/// Entry point for the CV app.
///
/// Wires the dependency graph:
///  - [InMemoryCvRepository] as the backing store (swapped for a platform-aware
///    implementation when the storage layer lands).
///  - [LibraryCubit] provided at the root so it outlives any single screen.
///  - [GoRouter] with two routes: `/` (Library) and `/editor/:id` (stub).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'src/repository/in_memory_cv_repository.dart';
import 'src/ui/library/library_cubit.dart';
import 'src/ui/library/library_screen.dart';

void main() {
  runApp(const CvApp());
}

class CvApp extends StatelessWidget {
  const CvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InMemoryCvRepository();
    final cubit = LibraryCubit(repository: repo);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => BlocProvider.value(
            value: cubit,
            child: LibraryScreen(
              onOpenVariant: (id) => ctx.push('/editor/$id'),
              onSettingsTapped: () {/* Settings — later ticket */},
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

    return MaterialApp.router(
      title: 'CV app',
      routerConfig: router,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2B6CB0),
        useMaterial3: true,
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
