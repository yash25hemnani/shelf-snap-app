import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/models/library_report.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

// Reports a public or unlisted library: a reason and an optional note
class ReportLibrarySheet extends ConsumerStatefulWidget {
  final LibraryModel library;

  const ReportLibrarySheet({super.key, required this.library});

  static Future<void> show(BuildContext context, LibraryModel library) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportLibrarySheet(library: library),
    );
  }

  @override
  ConsumerState<ReportLibrarySheet> createState() => _ReportLibrarySheetState();
}

class _ReportLibrarySheetState extends ConsumerState<ReportLibrarySheet> {
  final _noteController = TextEditingController();

  ReportReason? _reason;
  bool _isSending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = AuthService().currentUser?.uid;
    final reason = _reason;
    if (uid == null || reason == null) return;

    final note = _noteController.text.trim();
    // Captured now: the sheet closes before the message shows
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSending = true);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .reportLibrary(
            LibraryReport(
              libraryId: widget.library.id!,
              libraryName: widget.library.name,
              reporterId: uid,
              reason: reason,
              note: note.isEmpty ? null : note,
            ),
          );
      messenger.showMessage('Report sent, thanks for letting us know');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Report library failed: $e');
      if (!mounted) return;
      setState(() => _isSending = false);
      messenger.showError("Couldn't send report");
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report ${widget.library.name}', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              "The owner isn't told who sent it",
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final reason in ReportReason.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  reason == _reason
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: reason == _reason
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(reason.label),
                onTap: () => setState(() => _reason = reason),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Anything else? (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSending || _reason == null ? null : _send,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
