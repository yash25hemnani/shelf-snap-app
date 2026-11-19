import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';

// Opens the library behind a shared link or QR code on its page, where a
// visitor can ask to join. The only way into an unlisted library.
class LibraryLinkService {
  const LibraryLinkService._();

  // Navigator and messenger are captured by the caller before any await
  static Future<void> open(
    WidgetRef ref,
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    String link,
  ) async {
    final handle = LibraryModel.parseHandle(link);
    if (handle == null) {
      messenger.showError("That isn't a ShelfSnap library link");
      return;
    }

    try {
      final library = await ref
          .read(libraryRepositoryProvider)
          .findLibraryByHandle(handle);
      if (library == null) {
        messenger.showError('No public or unlisted library at this link');
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => LibraryDetailScreen(library: library),
        ),
      );
    } catch (e) {
      debugPrint('Open library link failed: $e');
      messenger.showError("Couldn't open the link, check your connection");
    }
  }
}
