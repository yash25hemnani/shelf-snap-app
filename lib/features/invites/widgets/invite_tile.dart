import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/notification_row.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';

// One pending invite with Decline and Accept
class InviteTile extends ConsumerStatefulWidget {
  final InviteModel invite;
  const InviteTile({super.key, required this.invite});

  @override
  ConsumerState<InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends ConsumerState<InviteTile> {
  bool _busy = false; // true while accept or decline is in flight

  Future<void> _answer(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Taken before the await: the row leaves the list as soon as the
    // invite changes locally, often before the write finishes
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(inviteRepositoryProvider);
    final invite = widget.invite;

    try {
      if (accept) {
        await repository.accept(invite);
        messenger.showMessage('Joined ${invite.libraryName}');
      } else {
        await repository.decline(invite);
        messenger.showMessage('Invite declined');
      }
    } catch (e) {
      debugPrint('${accept ? 'Accept' : 'Decline'} invite failed: $e');
      if (mounted) setState(() => _busy = false);
      messenger.showError(
        accept
            ? "Couldn't join, check your connection"
            : "Couldn't decline, check your connection",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    const bold = TextStyle(fontWeight: FontWeight.w600);

    return NotificationRow(
      avatarSeed: invite.fromUid,
      message: TextSpan(
        children: [
          TextSpan(text: '@${invite.fromUsername}', style: bold),
          const TextSpan(text: ' invited you to '),
          TextSpan(text: invite.libraryName, style: bold),
        ],
      ),
      createdAt: invite.createdAt,
      acceptLabel: 'Accept',
      busy: _busy,
      onAccept: () => _answer(true),
      onDecline: () => _answer(false),
    );
  }
}
