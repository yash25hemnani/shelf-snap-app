import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

// A QR code of the library's link, to print for a café counter or show on
// a phone. Phone cameras open the web catalog, whose Join button opens the
// app; the scanner on the Libraries screen opens the library directly.
// The card itself is what Share sends, so the picture matches the sheet.
class LibraryQrSheet extends StatefulWidget {
  final LibraryModel library;

  const LibraryQrSheet({super.key, required this.library});

  static Future<void> show(BuildContext context, LibraryModel library) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LibraryQrSheet(library: library),
    );
  }

  @override
  State<LibraryQrSheet> createState() => _LibraryQrSheetState();
}

class _LibraryQrSheetState extends State<LibraryQrSheet> {
  // Finds the card's drawing, to turn it into the shared picture
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _copy(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showMessage('Link copied, share it to invite people');
  }

  Future<void> _share(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 3x the screen size, sharp enough to print
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw Exception('No image');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: ['${widget.library.handle}-qr.png'],
          // Apps that drop the picture still get the link
          text: url,
        ),
      );
    } catch (e) {
      debugPrint('share QR failed: $e');
      messenger.showError("Couldn't share the code, try Copy link");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final textTheme = Theme.of(context).textTheme;
    final url = ApiConfig.catalogUrl(library.handle!);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                // Solid white with a border, so the code keeps its quiet
                // zone and the shared picture isn't see-through
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        library.name,
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        library.isPublic
                            ? 'Scan to see the books'
                            : 'Unlisted: only people with this code or link '
                                  'can open it',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: url,
                        size: 220,
                        backgroundColor: AppColors.background,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.text,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : () => _share(url),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(url),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
