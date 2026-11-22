import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/repositories/loan_repository.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

final loanRepositoryProvider = Provider((ref) => LoanRepository());

// The signed-in user's borrowed or lent loans, newest first
final loansProvider = StreamProvider.autoDispose
    .family<List<LoanModel>, LoanDirection>((ref, direction) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);

      final repository = ref.watch(loanRepositoryProvider);
      if (direction == LoanDirection.borrowed) {
        return repository.watchLoans(direction, userId);
      }

      // Only the ids are watched, so a library's book count changing doesn't
      // restart the query. Null while the libraries are still loading.
      final ids = ref.watch(
        userLibrariesProvider(userId).select(
          (libraries) => libraries.valueOrNull
              ?.where((l) => l.id != null && l.canEdit(userId))
              .map((l) => l.id!)
              .join(','),
        ),
      );
      if (ids == null) return const Stream.empty();

      return repository.watchLoans(
        direction,
        userId,
        libraryIds: ids.isEmpty ? const [] : ids.split(','),
      );
    });

// The signed-in user's open loan on one book, or null; for borrowers
final myBookLoanProvider = StreamProvider.autoDispose
    .family<LoanModel?, ({String libraryId, String bookId})>((ref, ids) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(null);

      return ref
          .watch(loanRepositoryProvider)
          .watchMyBookLoan(ids.libraryId, ids.bookId, userId);
    });

// Copies of one library's books out on loan, overdue first, then the
// soonest due; loans with no due date last
final libraryLentLoansProvider = StreamProvider.autoDispose
    .family<List<LoanModel>, String>(
      (ref, libraryId) => ref
          .watch(loanRepositoryProvider)
          .watchLibraryLentLoans(libraryId)
          .map(
            (loans) => [...loans]
              ..sort((a, b) {
                final byOverdue = (b.isOverdue ? 1 : 0) - (a.isOverdue ? 1 : 0);
                if (byOverdue != 0) return byOverdue;
                final ad = a.dueOn, bd = b.dueOn;
                if (ad == null || bd == null) {
                  return (ad == null ? 1 : 0) - (bd == null ? 1 : 0);
                }
                return ad.compareTo(bd);
              }),
          ),
    );

// Requested, approved and lent loans for one book, for editors on its
// book page. Oldest request first, so people are answered in order.
final bookLoansProvider = StreamProvider.autoDispose
    .family<List<LoanModel>, ({String libraryId, String bookId})>(
      (ref, ids) => ref
          .watch(loanRepositoryProvider)
          .watchBookLoans(ids.libraryId, ids.bookId)
          .map(
            (loans) => [...loans]
              ..sort(
                (a, b) => (a.requestedOn ?? DateTime.now()).compareTo(
                  b.requestedOn ?? DateTime.now(),
                ),
              ),
          ),
    );
