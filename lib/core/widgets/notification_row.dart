import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/time_ago.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';

// One thing to answer: who it's from, a sentence, when it came, and a
// muted Decline next to the main action. Used for invites and join requests.
class NotificationRow extends StatelessWidget {
  final String avatarSeed;
  final InlineSpan message;
  final DateTime createdAt;
  final String acceptLabel;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const NotificationRow({
    super.key,
    required this.avatarSeed,
    required this.message,
    required this.createdAt,
    required this.acceptLabel,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayAvatar(seed: avatarSeed, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(message, style: textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  timeAgo(createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy ? null : onDecline,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    // Fixed width, so the spinner doesn't shrink the button
                    FilledButton(
                      onPressed: busy ? null : onAccept,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 40),
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(acceptLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// White bordered card holding rows with dividers between them. Its height
// animates, so an answered row slides away instead of vanishing.
class NotificationGroup extends StatelessWidget {
  final List<Widget> children;

  const NotificationGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
