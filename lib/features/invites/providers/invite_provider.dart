import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/repositories/invite_repository.dart';

final inviteRepositoryProvider = Provider((ref) => InviteRepository());

final incomingInvitesProvider =
    StreamProvider.family<List<InviteModel>, String>(
      (ref, uid) => ref.watch(inviteRepositoryProvider).watchIncoming(uid),
    );

// Invites to a library the signed-in user sent that nobody has answered,
// so the invite sheet can list them and doesn't offer those people again
final pendingSentInvitesProvider = StreamProvider.autoDispose
    .family<List<InviteModel>, String>((ref, libraryId) {
      final uid = ref.watch(currentUidProvider).valueOrNull;
      if (uid == null) return Stream.value(const []);

      return ref
          .watch(inviteRepositoryProvider)
          .watchPendingSent(libraryId, uid);
    });
