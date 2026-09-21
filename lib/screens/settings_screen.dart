import 'package:flutter/material.dart';

/// Placeholder — no settings exist yet. Kept as its own screen so the
/// bottom navigation has somewhere to point; fill in as settings get asked
/// for.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Text(
          'Nothing here yet.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
