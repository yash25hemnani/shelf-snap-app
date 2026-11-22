import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/widgets/loan_tile.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';

// Search box over a library's books, then either the search results or
// the newest books with paging. Editors can also switch to the copies out
// on loan, and long-press books to hide, show or remove several at once.
class BooksTab extends ConsumerStatefulWidget {
  final String libraryId;
  // False for members who only view and for visitors; changes the empty
  // text and turns off the editor tools
  final bool canAdd;

  const BooksTab({super.key, required this.libraryId, this.canAdd = false});

  @override
  ConsumerState<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<BooksTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Editors only: showing the loans list instead of the books
  bool _lentOnly = false;
  // Books picked in select mode, by id; empty means not selecting
  final Map<String, BookModel> _selected = {};
  bool _busy = false; // a bulk action is in flight

  bool get _selecting => _selected.isNotEmpty;

  // Waits for a pause in typing before searching
  void _onChanged(String text) {
    setState(() {}); // shows or hides the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(bookSearchQueryProvider(widget.libraryId).notifier).state = text;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(bookSearchQueryProvider(widget.libraryId).notifier).state = '';
    setState(() {});
  }

  void _toggle(BookModel book) {
    final id = book.id;
    if (id == null) return;
    setState(() {
      if (_selected.remove(id) == null) _selected[id] = book;
    });
  }

  void _open(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
    );
  }

  Future<void> _setVisibility(BookVisibility visibility) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selected.keys.toList();

    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateVisibilityMany(widget.libraryId, ids, visibility);
      final n = ids.length == 1 ? '1 book' : '${ids.length} books';
      messenger.showMessage(
        visibility == BookVisibility.private
            ? 'Hid $n from viewers'
            : 'Showed $n to everyone in the library',
      );
      if (mounted) setState(_selected.clear);
    } catch (e) {
      debugPrint('updateVisibilityMany failed: $e');
      messenger.showError("Couldn't save, check your connection");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final books = _selected.values.toList();
    final n = books.length == 1 ? '1 book' : '${books.length} books';

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove $n?',
      message:
          'Every copy leaves the library. Books out on loan stay until '
          "they're back.",
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final skipped = await ref
          .read(libraryRepositoryProvider)
          .deleteBooks(widget.libraryId, books);
      final removed = books.length - skipped.length;
      final removedText = removed == 1 ? '1 book' : '$removed books';
      messenger.showMessage(switch (skipped.length) {
        0 => 'Removed $removedText',
        1 => 'Removed $removedText, kept 1 on loan',
        final s => 'Removed $removedText, kept $s on loan',
      });
      if (mounted) setState(_selected.clear);
    } catch (e) {
      debugPrint('deleteBooks failed: $e');
      messenger.showError("Couldn't remove books, check your connection");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(bookSearchQueryProvider(widget.libraryId));
    // A single letter isn't searchable, so the full list stays
    final searching = BookModel.sanitizeWords(query).isNotEmpty;
    final lentOnly = widget.canAdd && _lentOnly;

    // Back leaves select mode before it leaves the page
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Column(
        children: [
          // White band under the field, so books scroll out of sight below it
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _selecting ? _buildSelectionBar() : _buildSearchField(),
          ),
          if (widget.canAdd && !_selecting) _buildFilters(),
          Expanded(
            child: lentOnly
                ? _buildLentOut()
                : searching
                ? _buildResults()
                : _buildAllBooks(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onChanged,
      enabled: !_lentOnly,
      autocorrect: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by title or author',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  // Same height as the search field, so the grid doesn't jump
  Widget _buildSelectionBar() {
    final count = _selected.length;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Done',
            onPressed: _busy ? null : () => setState(_selected.clear),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$count selected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Hide from viewers',
              onPressed: () => _setVisibility(BookVisibility.private),
              icon: const Icon(Icons.visibility_off_outlined),
            ),
            IconButton(
              tooltip: 'Show to everyone',
              onPressed: () => _setVisibility(BookVisibility.public),
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'Remove from library',
              onPressed: _remove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All books'),
            selected: !_lentOnly,
            onSelected: (_) => setState(() => _lentOnly = false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Lent out'),
            selected: _lentOnly,
            onSelected: (_) => setState(() => _lentOnly = true),
          ),
        ],
      ),
    );
  }

  Widget _buildLentOut() {
    final loansAsync = ref.watch(libraryLentLoansProvider(widget.libraryId));

    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) {
          return const Center(child: Text('No copies out on loan'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: loans.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              LoanTile(loan: loans[i], direction: LoanDirection.lent),
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildResults() {
    final resultsAsync = ref.watch(libraryBookSearchProvider(widget.libraryId));

    return resultsAsync.when(
      // Keeps the old results on screen while the next search runs
      skipLoadingOnReload: true,
      data: (books) {
        if (books.isEmpty) {
          return const Center(child: Text('No books match your search'));
        }
        return _buildGrid(books);
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAllBooks() {
    final booksAsync = ref.watch(libraryBooksProvider(widget.libraryId));

    return booksAsync.when(
      // Keeps the grid and its scroll position while the next page loads
      skipLoadingOnReload: true,
      data: (books) {
        if (books.isEmpty) {
          return Center(
            child: Text(
              widget.canAdd
                  ? 'No Books Yet. Scan a Shelf or Add Manually!'
                  : 'No books here yet',
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            final limit = ref.read(booksLimitProvider(widget.libraryId));
            // A full page means there may be more books after it
            final hasMore = books.length >= limit;
            if (n.metrics.extentAfter < 400 &&
                hasMore &&
                !booksAsync.isLoading) {
              ref.read(booksLimitProvider(widget.libraryId).notifier).state +=
                  booksPageSize;
            }
            return false;
          },
          child: _buildGrid(books, loadingMore: booksAsync.isLoading),
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  // Grid of book covers. A tap opens the book, or picks it while selecting;
  // a long press starts selecting (editors only).
  Widget _buildGrid(List<BookModel> books, {bool loadingMore = false}) {
    return GridView.builder(
      // Top is small since the search band already leaves a gap
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 210,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      // Adds a spinner cell at the end while the next page loads
      itemCount: books.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final book = books[index];
        return BookCard(
          book: book,
          selected: _selected.containsKey(book.id),
          onTap: _busy
              ? null
              : _selecting
              ? () => _toggle(book)
              : () => _open(book),
          onLongPress: widget.canAdd && !_busy ? () => _toggle(book) : null,
        );
      },
    );
  }
}
