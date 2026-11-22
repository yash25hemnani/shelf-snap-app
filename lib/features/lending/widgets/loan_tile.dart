import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';

// One loan: cover, title, who or where, the latest date and the status.
// Tapping it opens the book's page.
class LoanTile extends ConsumerWidget {
  final LoanModel loan;
  // Borrowed shows the library; lent shows who has the book
  final LoanDirection direction;

  const LoanTile({super.key, required this.loan, required this.direction});

  // The book page needs the whole book, so it's read once before opening
  Future<void> _openBook(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final book = await ref
          .read(libraryRepositoryProvider)
          .watchBook(loan.libraryId, loan.bookId)
          .first;
      if (!context.mounted) return;

      if (book == null) {
        messenger.showMessage('This book is no longer in the library');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      );
    } on FirebaseException catch (e) {
      // A loan added by hand can go to someone outside the library, and
      // only members can read its books
      if (e.code == 'permission-denied') {
        messenger.showMessage(
          "You're not in ${loan.libraryName}, so the book page is closed",
        );
        return;
      }
      debugPrint('open loan book failed: $e');
      messenger.showError("Couldn't open the book, check your connection");
    } catch (e) {
      debugPrint('open loan book failed: $e');
      messenger.showError("Couldn't open the book, check your connection");
    }
  }

  String get _dateLine {
    final due = loan.dueOn;
    return switch (loan.status) {
      LoanStatus.requested => [
        'Asked',
        if (loan.requestedOn case final asked?) dayMonth(asked),
        if (loan.collectOn case final collect?) '· collects ${dayMonth(collect)}',
      ].join(' '),
      LoanStatus.approved => [
        'Approved',
        if (loan.collectOn case final collect?) '· collects ${dayMonth(collect)}',
        if (due != null) '· return by ${dayMonth(due)}',
      ].join(' '),
      LoanStatus.lent => [
        if (loan.lentOn case final lent?) 'Since ${dayMonth(lent)}' else 'Out',
        if (due != null)
          loan.isOverdue
              ? '· overdue since ${dayMonth(due)}'
              : '· return by ${dayMonth(due)}',
      ].join(' '),
      // The status line already says what happened, so just the date
      LoanStatus.returned || LoanStatus.lost =>
        loan.returnedOn == null ? '' : 'On ${dayMonth(loan.returnedOn!)}',
      LoanStatus.rejected || LoanStatus.cancelled =>
        loan.respondedOn == null ? '' : 'On ${dayMonth(loan.respondedOn!)}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = loan.coverUrl;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    final who = direction == LoanDirection.borrowed
        ? loan.libraryName
        : (loan.borrowerName.isEmpty ? 'Someone' : loan.borrowerName);

    final statusColor = loan.isOverdue
        ? AppColors.error
        : switch (loan.status) {
            LoanStatus.requested => AppColors.warning,
            LoanStatus.approved || LoanStatus.lent => AppColors.accent,
            LoanStatus.returned => AppColors.primary,
            LoanStatus.lost => AppColors.error,
            LoanStatus.rejected || LoanStatus.cancelled =>
              AppColors.textSecondary,
          };

    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint)),
    );

    // Material + InkWell so the tap ripple stays inside the rounded border
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _openBook(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: coverUrl == null
                      ? placeholder
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.bookTitle,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      who,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loan.isOverdue ? 'Overdue' : loan.status.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    if (_dateLine case final line when line.isNotEmpty)
                      Text(
                        line,
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}
