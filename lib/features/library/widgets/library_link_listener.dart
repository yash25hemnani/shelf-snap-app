import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/services/library_link_service.dart';

// Opens a library when the app is launched from a library link: the Join
// button on its web catalog (shelfsnap://lib/{handle}). Sits above the
// signed-in app, so a link that started the app while signed out opens once
// the user has signed in.
class LibraryLinkListener extends ConsumerStatefulWidget {
  final Widget child;

  const LibraryLinkListener({super.key, required this.child});

  @override
  ConsumerState<LibraryLinkListener> createState() =>
      _LibraryLinkListenerState();
}

class _LibraryLinkListenerState extends ConsumerState<LibraryLinkListener> {
  StreamSubscription<Uri>? _links;

  void _onLink(Uri uri) {
    // Only library links count
    if (!uri.toString().contains('/lib/') || !mounted) return;
    LibraryLinkService.open(
      ref,
      Navigator.of(context),
      ScaffoldMessenger.of(context),
      uri.toString(),
    );
  }

  @override
  void initState() {
    super.initState();
    // Sends the link that launched the app first, then any later ones
    _links = AppLinks().uriLinkStream.listen(_onLink);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
