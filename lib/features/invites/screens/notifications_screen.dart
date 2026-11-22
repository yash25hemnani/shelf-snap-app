import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/notification_row.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/widgets/invite_tile.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/widgets/join_request_tile.dart';

// Pending invites for the signed-in user, then requests to join the
// libraries they own, each group in its own card
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUser!.uid;
    final invitesAsync = ref.watch(incomingInvitesProvider(uid));
    final requestsAsync = ref.watch(ownerJoinRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: invitesAsync.when(
        data: (invites) {
          // A failed requests query shouldn't hide the invites
          final requests = requestsAsync.valueOrNull ?? const [];
          if (invites.isEmpty && requests.isEmpty) return const _Empty();

          // Answered invites and requests leave their streams, so their
          // rows disappear and the group card shrinks around them
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (invites.isNotEmpty) ...[
                const _Heading('Invites'),
                NotificationGroup(
                  children: [
                    for (final invite in invites)
                      InviteTile(key: ValueKey(invite.id), invite: invite),
                  ],
                ),
              ],
              if (requests.isNotEmpty) ...[
                if (invites.isNotEmpty) const SizedBox(height: 24),
                const _Heading('Want to join your libraries'),
                NotificationGroup(
                  children: [
                    for (final request in requests)
                      JoinRequestTile(
                        key: ValueKey('${request.libraryId}_${request.uid}'),
                        request: request,
                        showLibrary: true,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
        error: (err, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Couldn't load notifications. Check your connection and "
              'open this page again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

// Nothing waiting: say what will show up here
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppColors.hint,
            ),
            const SizedBox(height: 16),
            Text('Nothing to answer', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Library invites and requests to join your libraries show '
              'up here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
