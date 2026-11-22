import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

// Fixes a library book's title, subtitle, authors or cover when a scan or
// the book API got them wrong
class EditBookSheet extends ConsumerStatefulWidget {
  final BookModel book;
  const EditBookSheet({super.key, required this.book});

  static Future<void> show(BuildContext context, BookModel book) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditBookSheet(book: book),
    );
  }

  @override
  ConsumerState<EditBookSheet> createState() => _EditBookSheetState();
}

class _EditBookSheetState extends ConsumerState<EditBookSheet> {
  final _formKey = GlobalKey<FormState>();

  // Unknown Title is a placeholder, so the field starts empty instead
  late final _title = TextEditingController(
    text: widget.book.title == BookModel.unknownTitle ? '' : widget.book.title,
  );
  late final _subtitle = TextEditingController(text: widget.book.subtitle);
  late final _authors = TextEditingController(
    text: widget.book.authors.join(', '),
  );
  late final _cover = TextEditingController(text: widget.book.coverUrl);

  bool _isSaving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _authors.dispose();
    _cover.dispose();
    super.dispose();
  }

  // Empty text is stored as null, so the page shows nothing for it
  String? _orNull(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  // "A, B" → [A, B], skipping blanks from stray commas
  List<String> get _authorList => _authors.text
      .split(',')
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();

  // The reading log follows the title and first author, so changing them
  // starts a fresh log for this book
  bool get _movesLog {
    final edited = BookModel(
      title: _title.text.trim(),
      authors: _authorList,
    ).readingKey;
    final before = widget.book.readingKey;
    return before != null && edited != before;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final book = widget.book;
    final libraryId = book.libraryId;
    final bookId = book.id;
    if (libraryId == null || bookId == null) return;

    setState(() => _isSaving = true);
    // Captured now: the sheet closes before the message shows
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateDetails(
            libraryId,
            bookId,
            title: _title.text.trim(),
            subtitle: _orNull(_subtitle),
            authors: _authorList,
            coverUrl: _orNull(_cover),
          );
      messenger.showMessage('Saved book details');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('updateDetails failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showError("Couldn't save, check your connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Bottom inset lifts the sheet above the keyboard; scrolls when the
    // keyboard leaves too little room for every field
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit details', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitle,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Subtitle (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authors,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Authors',
                  helperText: 'Separate more than one with commas',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cover,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Cover image link (optional)',
                  hintText: 'https://…',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final uri = Uri.tryParse(text);
                  final ok =
                      uri != null &&
                      (uri.scheme == 'https' || uri.scheme == 'http') &&
                      uri.host.isNotEmpty;
                  return ok ? null : 'Paste a full web link to an image';
                },
              ),
              if (_movesLog) ...[
                const SizedBox(height: 12),
                Text(
                  'Your reading log for this book stays under the old title. '
                  'Tracking it again starts a new one.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
