import 'package:flutter/material.dart';

import 'add_book_screen.dart';
import 'catalog_screen.dart';
import 'settings_screen.dart';

/// The app's root navigation shell: a bottom row of floating buttons
/// switches between Add / My Books / Settings, with My Books as the
/// default screen. Each screen stays alive via [IndexedStack], so
/// switching tabs and back preserves things like the catalog's search
/// text and an in-progress add flow.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _defaultIndex = 1; // My Books

  int _selectedIndex = _defaultIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [AddBookScreen(), CatalogScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShellButton(
                icon: Icons.add,
                label: 'Add',
                selected: _selectedIndex == 0,
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              _ShellButton(
                icon: Icons.menu_book,
                label: 'My Books',
                selected: _selectedIndex == 1,
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
              _ShellButton(
                icon: Icons.settings,
                label: 'Settings',
                selected: _selectedIndex == 2,
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellButton extends StatelessWidget {
  const _ShellButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag:
              null, // several FABs on screen at once; no hero animation needed
          onPressed: onPressed,
          backgroundColor: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          foregroundColor: selected
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : null,
            fontWeight: selected ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}
