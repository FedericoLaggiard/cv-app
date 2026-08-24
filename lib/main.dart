/// Entry point for the CV app.
///
/// The UI is not wired yet — this iteration ships the domain fundamentals
/// (schema, JSON codec, validation, repository) required by tickets 01-04.
/// The Library / Editor / Preview screens land in ticket 07.
library;

import 'package:flutter/material.dart';

void main() {
  runApp(const CvApp());
}

class CvApp extends StatelessWidget {
  const CvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'CV app',
      home: _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'CV app — foundation layer.\n'
            'UI (Libreria / Editor / Anteprima) landing con ticket 07.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
