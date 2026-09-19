import 'package:flutter/material.dart';

import 'isbn_entry_flow.dart';

/// For when a barcode won't scan or isn't present: type the ISBN by hand,
/// then go through the same lookup-and-confirm flow as scanning.
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isbn = _controller.text.trim();
    if (isbn.isEmpty) return;
    setState(() => _submitting = true);
    await handleIsbnEntered(context, isbn);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter ISBN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'ISBN',
                hintText: 'e.g. 9780141439518',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Looking up...' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
