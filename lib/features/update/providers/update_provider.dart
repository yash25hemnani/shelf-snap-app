import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/update/models/app_release.dart';
import 'package:shelf_snap/features/update/services/update_service.dart';

final updateServiceProvider = Provider((ref) => UpdateService());

// Checked once per app start; not autoDispose, so switching tabs doesn't
// call GitHub again
final availableUpdateProvider = FutureProvider<AppRelease?>((ref) {
  return ref.read(updateServiceProvider).checkForUpdate();
});

// The installed version, shown on the card next to the new one
final installedVersionProvider = FutureProvider<String>((ref) {
  return ref.read(updateServiceProvider).installedVersion();
});

// "Later" hides the card until the next app start
final updateDismissedProvider = StateProvider<bool>((ref) => false);
