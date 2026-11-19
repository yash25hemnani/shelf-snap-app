import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Full-screen QR scanner that closes with the first code it reads, for
// opening a library from its QR code
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // The camera keeps reporting the code, so only the first one pops
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (_done || value == null) return;
    _done = true;
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a library QR code'),
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
