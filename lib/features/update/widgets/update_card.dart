import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/update/models/app_release.dart';
import 'package:shelf_snap/features/update/providers/update_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Stage { idle, downloading, installing, failed }

// Top of Home when GitHub has a newer APK. Looks like a page with a gold
// ribbon bookmark hanging from its top edge, marking the new version.
// Download and install fetches the APK inside the app and opens Android's
// installer; if that fails, the APK can still be opened in the browser.
class UpdateCard extends ConsumerStatefulWidget {
  const UpdateCard({super.key});

  @override
  ConsumerState<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends ConsumerState<UpdateCard> {
  StreamSubscription<OtaEvent>? _download;
  _Stage _stage = _Stage.idle;
  double? _progress; // 0 to 1 while downloading, null until the first event
  String? _error;
  bool _showAllNotes = false;

  void _fail(String message) {
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final percent = double.tryParse(event.value ?? '');
        setState(() {
          _stage = _Stage.downloading;
          _progress = percent == null ? null : (percent / 100).clamp(0, 1);
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _stage = _Stage.installing);
      case OtaStatus.ALREADY_RUNNING_ERROR:
        // A download is already going; keep showing progress
        setState(() => _stage = _Stage.downloading);
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail('Allow ShelfSnap to install apps in Android settings, then try again');
      case OtaStatus.CANCELED:
        setState(() => _stage = _Stage.idle);
      default:
        debugPrint('ota update failed: ${event.status} ${event.value}');
        _fail("The download didn't finish. Try again or use the browser.");
    }
  }

  void _install(AppRelease release) {
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _error = null;
    });
    try {
      _download?.cancel();
      _download = OtaUpdate()
          .execute(
            release.apkUrl,
            destinationFilename: 'shelfsnap-${release.version}.apk',
          )
          .listen(
            _onEvent,
            onError: (Object e) {
              debugPrint('ota update failed: $e');
              if (mounted) {
                _fail("The download didn't finish. Try again or use the browser.");
              }
            },
          );
    } catch (e) {
      debugPrint('ota update failed: $e');
      _fail("The download didn't start. Try again or use the browser.");
    }
  }

  // Fallback: Android's browser downloads the APK and the user opens it
  Future<void> _openInBrowser(AppRelease release) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(release.apkUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) messenger.showError("Couldn't open the browser");
    } catch (e) {
      debugPrint('launchUrl failed: $e');
      messenger.showError("Couldn't open the browser");
    }
  }

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(availableUpdateProvider).valueOrNull;
    final dismissed = ref.watch(updateDismissedProvider);
    if (release == null || dismissed) return const SizedBox.shrink();

    final installed = ref.watch(installedVersionProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final busy = _stage == _Stage.downloading || _stage == _Stage.installing;
    final notes = release.notes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Right padding keeps the heading clear of the ribbon
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    'Version ${release.version} is ready',
                    // GoogleFonts.dmSans so the w700 font file loads
                    style: GoogleFonts.dmSans(
                      textStyle: textTheme.titleMedium,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if (installed != null)
                  Text(
                    "You're on $installed",
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Tapping the notes shows them all; long ones start at 3 lines
                  GestureDetector(
                    onTap: () => setState(() => _showAllNotes = !_showAllNotes),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: Text(
                        notes,
                        maxLines: _showAllNotes ? null : 3,
                        overflow: _showAllNotes
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.text,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (busy)
                  _Progress(
                    installing: _stage == _Stage.installing,
                    fraction: _progress,
                  )
                else ...[
                  if (_error case final error?) ...[
                    Text(
                      error,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _install(release),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _stage == _Stage.failed
                              ? 'Try again'
                              : 'Download and install',
                        ),
                      ),
                      if (_stage == _Stage.failed)
                        TextButton(
                          onPressed: () => _openInBrowser(release),
                          child: const Text('Use the browser'),
                        )
                      else
                        TextButton(
                          onPressed: () => ref
                                  .read(updateDismissedProvider.notifier)
                                  .state =
                              true,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Later'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Positioned(top: 0, right: 20, child: _Ribbon()),
        ],
      ),
    );
  }
}

// Download bar in the same style as reading progress, with what's happening
// above it
class _Progress extends StatelessWidget {
  final bool installing;
  final double? fraction;

  const _Progress({required this.installing, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final fraction = this.fraction;
    final label = installing
        ? 'Opening the installer'
        : fraction == null
        ? 'Starting the download'
        : 'Downloading ${(fraction * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            // Indeterminate before the first event and while installing
            value: installing ? null : fraction,
            minHeight: 8,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Gold ribbon bookmark hanging from the card's top edge, its end cut into
// a V like a real one
class _Ribbon extends StatelessWidget {
  const _Ribbon();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: const SizedBox(
        width: 18,
        height: 34,
        child: ColoredBox(color: AppColors.secondary),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 7)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_RibbonClipper oldClipper) => false;
}
