import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
import 'package:shelf_snap/features/scanner/screens/qr_scan_screen.dart';

// Opens a public or unlisted library from its web address or QR code.
// The only way into an unlisted library from the app.
class OpenLibraryLinkSheet extends ConsumerStatefulWidget {
  const OpenLibraryLinkSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OpenLibraryLinkSheet(),
    );
  }

  @override
  ConsumerState<OpenLibraryLinkSheet> createState() =>
      _OpenLibraryLinkSheetState();
}

class _OpenLibraryLinkSheetState extends ConsumerState<OpenLibraryLinkSheet> {
  final _controller = TextEditingController();

  bool _isLoading = false;
  // Shown under the field: a bad address, or no library behind it
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || !mounted) return;
    _controller.text = code;
    await _open();
  }

  Future<void> _open() async {
    final handle = LibraryModel.parseHandle(_controller.text);
    if (handle == null) {
      setState(() => _error = 'Paste a library link, like …/l/book-buddies');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    // Captured now: this sheet closes before the library opens
    final navigator = Navigator.of(context);

    try {
      final library = await ref
          .read(libraryRepositoryProvider)
          .findLibraryByHandle(handle);
      if (!mounted) return;
      if (library == null) {
        setState(() {
          _isLoading = false;
          _error = 'No public or unlisted library at this address';
        });
        return;
      }
      navigator
        ..pop()
        ..push(
          MaterialPageRoute(
            builder: (_) => LibraryDetailScreen(library: library),
          ),
        );
    } catch (e) {
      debugPrint('Open library link failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't open the link, check your connection";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Bottom inset lifts the sheet above the keyboard
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Open a library link', style: textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            'For libraries shared with you by link or QR code',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            // Top-aligned, so error text doesn't move the button
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _open(),
                  decoration: InputDecoration(
                    labelText: 'Link or web address',
                    errorText: _error,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Scan'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading || _controller.text.trim().isEmpty
                ? null
                : _open,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Open library'),
          ),
        ],
      ),
    );
  }
}
