import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/screens/lend_copy_screen.dart';
import 'package:shelf_snap/features/lending/widgets/loan_tile.dart';

// Books the user borrowed and books lent out from libraries they manage,
// switched with chips at the top
class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  LoanDirection _direction = LoanDirection.borrowed;

  Future<void> _lend() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LendCopyScreen()),
    );
    if (name != null) messenger.showMessage('Lent to $name');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loansAsync = ref.watch(loansProvider(_direction));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
        actions: [
          TextButton.icon(
            onPressed: _lend,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add manually'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final direction in LoanDirection.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        direction == LoanDirection.borrowed
                            ? 'Borrowed'
                            : 'Lent',
                      ),
                      selected: _direction == direction,
                      onSelected: (_) =>
                          setState(() => _direction = direction),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: loansAsync.when(
              data: (loans) {
                if (loans.isEmpty) {
                  return Center(
                    child: Text(
                      _direction == LoanDirection.borrowed
                          ? 'No borrowed books yet'
                          : 'Nothing lent out yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                // Open loans first; sort is stable, so each group stays
                // newest first
                final sorted = [...loans]
                  ..sort(
                    (a, b) => (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0),
                  );

                return ListView.separated(
                  // Room at the bottom so the button doesn't cover the last row
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      LoanTile(loan: sorted[i], direction: _direction),
                );
              },
              error: (e, _) => Center(child: Text('Could not load loans: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
