import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

// A QR code of the library's web address, to print for a café counter or
// show on a phone. Phone cameras open the web catalog; the app's
// "Open a library link" scanner opens the library itself.
class LibraryQrSheet extends StatelessWidget {
  final LibraryModel library;

  const LibraryQrSheet({super.key, required this.library});

  static Future<void> show(BuildContext context, LibraryModel library) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LibraryQrSheet(library: library),
    );
  }

  Future<void> _copy(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showMessage('Web address copied');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final url = ApiConfig.catalogUrl(library.handle!);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  : 'Unlisted: only people with this code or link can open it',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // White card with a border, so the code keeps its quiet zone
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: QrImageView(
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
              ),
            ),
            const SizedBox(height: 16),
            Text(
              url.replaceFirst(RegExp(r'^https?://'), ''),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _copy(context, url),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy link'),
            ),
          ],
        ),
      ),
    );
  }
}
