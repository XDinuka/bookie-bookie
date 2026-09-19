import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/book.dart';
import '../widgets/book_list_tile.dart';
import 'book_form_screen.dart';
import 'manual_entry_screen.dart';
import 'photo_capture_screen.dart';
import 'scan_screen.dart';

/// The whole app's home screen: search the catalog, open an entry to
/// review/edit it, delete it, or start one of the three add-book flows.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  List<Book> _books = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final repository = context.read<BookRepository>();
    final books = await repository.search(_searchController.text);
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _delete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text(book.title ?? book.isbn ?? 'This entry'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<BookRepository>().delete(book.id!);
      await _reload();
    }
  }

  Future<void> _openAddMenu() async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan barcode'),
              onTap: () => Navigator.of(context).pop(_AddChoice.scan),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Enter ISBN manually'),
              onTap: () => Navigator.of(context).pop(_AddChoice.manual),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture photos'),
              onTap: () => Navigator.of(context).pop(_AddChoice.photos),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    final screen = switch (choice) {
      _AddChoice.scan => const ScanScreen(),
      _AddChoice.manual => const ManualEntryScreen(),
      _AddChoice.photos => const PhotoCaptureScreen(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookie Bookie')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by title, author, or ISBN',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _reload(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _books.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: _books.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final book = _books[index];
                      return Dismissible(
                        key: ValueKey(book.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline),
                        ),
                        confirmDismiss: (_) async {
                          await _delete(book);
                          return false; // _reload() already refreshes the list
                        },
                        child: BookListTile(
                          book: book,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookFormScreen(existingBook: book),
                              ),
                            );
                            await _reload();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _AddChoice { scan, manual, photos }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No books yet. Tap + to scan a barcode, type an ISBN, or capture photos.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
