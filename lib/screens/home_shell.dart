import 'package:flutter/material.dart';

import 'add_book_screen.dart';
import 'catalog_screen.dart';
import 'settings_screen.dart';

/// The app's root navigation shell: a single floating bar at the bottom —
/// not three separate floating buttons — holds the Add / My Books /
/// Settings destinations, with My Books as the default. Each screen stays
/// alive via [IndexedStack], so switching tabs and back preserves things
/// like the catalog's search text and an in-progress add flow.
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
        minimum: const EdgeInsets.only(bottom: 12),
        // A plain Row here, not Center/Align: those expand to fill whatever
        // bounded height Scaffold offers the bottomNavigationBar slot,
        // which starves `body` of space (and, inside an IndexedStack, can
        // leave a sibling's sliver list with ~0 height to lay out into,
        // silently mounting none of its children). Row sizes to its
        // content's height regardless, while still centering horizontally.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShellNavItem(
                      icon: Icons.add,
                      label: 'Add',
                      selected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                    _ShellNavItem(
                      icon: Icons.menu_book,
                      label: 'My Books',
                      selected: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    _ShellNavItem(
                      icon: Icons.settings,
                      label: 'Settings',
                      selected: _selectedIndex == 2,
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment of the floating nav bar — sized to its own content (icon +
/// label), not stretched to fill space, so the bar as a whole stays
/// compact instead of spanning the screen width.
class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
