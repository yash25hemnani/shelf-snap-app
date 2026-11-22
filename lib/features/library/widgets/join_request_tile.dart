import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/notification_row.dart';
import 'package:shelf_snap/features/library/models/join_request.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

// One request to join a library, with Decline and Approve for the owner.
// Notifications show which library it's for; the Members tab doesn't need to.
class JoinRequestTile extends ConsumerStatefulWidget {
  final JoinRequest request;
  final bool showLibrary;

  const JoinRequestTile({
    super.key,
    required this.request,
    this.showLibrary = false,
  });

  @override
  ConsumerState<JoinRequestTile> createState() => _JoinRequestTileState();
}

class _JoinRequestTileState extends ConsumerState<JoinRequestTile> {
  bool _busy = false; // true while approve or decline is in flight

  Future<void> _answer(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);

    // The row leaves the list as soon as the request is deleted locally,
    // often before the write finishes
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(libraryRepositoryProvider);
    final request = widget.request;

    try {
      if (approve) {
        await repository.approveJoinRequest(request.libraryId, request.uid);
        messenger.showMessage(
          '@${request.username} joined ${request.libraryName}',
        );
      } else {
        await repository.deleteJoinRequest(request.libraryId, request.uid);
        messenger.showMessage('Request declined');
      }
    } catch (e) {
      debugPrint('${approve ? 'Approve' : 'Decline'} join request failed: $e');
      if (mounted) setState(() => _busy = false);
      messenger.showError(
        approve ? "Couldn't approve request" : "Couldn't decline request",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    const bold = TextStyle(fontWeight: FontWeight.w600);

    return NotificationRow(
      avatarSeed: request.uid,
      message: TextSpan(
        children: [
          TextSpan(text: '@${request.username}', style: bold),
          if (widget.showLibrary) ...[
            const TextSpan(text: ' wants to join '),
            TextSpan(text: request.libraryName, style: bold),
          ] else
            const TextSpan(text: ' wants to join'),
        ],
      ),
      createdAt: request.createdAt,
      acceptLabel: 'Approve',
      busy: _busy,
      onAccept: () => _answer(true),
      onDecline: () => _answer(false),
    );
  }
}
