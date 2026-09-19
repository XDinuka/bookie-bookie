import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'isbn_entry_flow.dart';

/// Point the camera at a book's ISBN barcode (EAN-13/EAN-8). The first
/// readable barcode pauses scanning and hands off to the shared
/// lookup-and-confirm flow.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );

  bool _handledOne = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledOne) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    _handledOne = true;
    await _controller.stop();
    if (!mounted) return;

    await handleIsbnEntered(context, code);

    if (!mounted) return;
    _handledOne = false;
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
