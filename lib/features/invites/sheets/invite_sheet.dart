import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

// Search people by username and invite them to a library. With the search
// box empty, it lists invites still waiting for an answer, which can be
// taken back.
class InviteSheet extends ConsumerStatefulWidget {
  final LibraryModel library;
  const InviteSheet({super.key, required this.library});

  static Future<void> show(BuildContext context, LibraryModel library) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteSheet(library: library),
    );
  }

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  final Set<String> _sent = {}; // uids invited while the sheet is open
  String? _sendingUid; // uid with a request in flight
  String? _cancellingId; // invite being taken back

  // The sheet's own messenger, so SnackBars show on top of the sheet
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Runs on every keystroke in the search box
  void _onChanged(String text) {
    setState(() {}); // swaps between the waiting list and the results
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _search(text));
  }

  Future<void> _search(String text) async {
    final users = await ref.read(userRepositoryProvider).searchUsers(text);

    if (!mounted || text != _searchController.text) return;

    // People already in the library can't be invited again
    setState(() {
      _results = users
          .where((u) => !widget.library.members.contains(u.uid))
          .toList();
    });
  }

  Future<void> _invite(UserModel to) async {
    final uid = AuthService().currentUser!.uid;

    // Your own profile, already loaded by AuthGate
    final me = ref.read(userProfileProvider(uid)).valueOrNull;
    final pending = ref
        .read(pendingSentInvitesProvider(widget.library.id!))
        .valueOrNull;
    if (me == null || _sendingUid != null) return;
    // Guards a tap that lands before the list above has loaded
    if (pending?.any((i) => i.toUid == to.uid) ?? false) return;

    setState(() => _sendingUid = to.uid);
    try {
      await ref
          .read(inviteRepositoryProvider)
          .sendInvite(library: widget.library, from: me, to: to);
      if (mounted) setState(() => _sent.add(to.uid));
    } catch (e) {
      debugPrint('sendInvite failed: $e');
      _messengerKey.currentState?.showError(
        "Couldn't invite @${to.username}, check your connection",
      );
    } finally {
      if (mounted) setState(() => _sendingUid = null);
    }
  }

  // No confirm: inviting them again is one tap away
  Future<void> _cancel(InviteModel invite, String name) async {
    if (_cancellingId != null) return;

    setState(() => _cancellingId = invite.id);
    try {
      await ref.read(inviteRepositoryProvider).cancel(invite);
      if (!mounted) return;
      setState(() => _sent.remove(invite.toUid));
      _messengerKey.currentState?.showMessage('Took back the invite to $name');
    } catch (e) {
      debugPrint('cancel invite failed: $e');
      _messengerKey.currentState?.showError(
        "Couldn't take back the invite, check your connection",
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        ref.watch(pendingSentInvitesProvider(widget.library.id!)).valueOrNull ??
        const <InviteModel>[];
    // Invites from earlier visits, plus ones sent just now (shown straight
    // away, before Firestore reports them)
    final invited = {for (final i in pending) i.toUid, ..._sent};
    final searching = _searchController.text.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;

    // Fixed height so the results list can scroll inside the sheet
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ScaffoldMessenger(
        key: _messengerKey,
        // Scaffold gives the messenger somewhere to show SnackBars
        // and shrinks its body above the keyboard
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onChanged,
                  autofocus: pending.isEmpty,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'Search by username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (searching)
                        for (final user in _results)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(user.name),
                            subtitle: Text('@${user.username}'),
                            trailing: invited.contains(user.uid)
                                ? const Text('Sent')
                                : FilledButton.tonal(
                                    // Disabled while any invite is sending
                                    onPressed: _sendingUid == null
                                        ? () => _invite(user)
                                        : null,
                                    child: _sendingUid == user.uid
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Invite'),
                                  ),
                          )
                      else if (pending.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            'Waiting for an answer',
                            style: textTheme.titleSmall,
                          ),
                        ),
                        for (final invite in pending)
                          _PendingInviteTile(
                            key: ValueKey(invite.id),
                            invite: invite,
                            busy: _cancellingId == invite.id,
                            onCancel: _cancellingId == null
                                ? (name) => _cancel(invite, name)
                                : null,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One unanswered invite, with the invitee's name once their profile loads
class _PendingInviteTile extends ConsumerWidget {
  final InviteModel invite;
  final bool busy;
  // Gets the name to show in the message; null while another is cancelling
  final void Function(String name)? onCancel;

  const _PendingInviteTile({
    super.key,
    required this.invite,
    required this.busy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(invite.toUid)).valueOrNull;
    final name = user?.name ?? 'Someone';
    final onCancel = this.onCancel;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name),
      subtitle: user == null ? null : Text('@${user.username}'),
      trailing: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onCancel == null ? null : () => onCancel(name),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Take back'),
            ),
    );
  }
}
