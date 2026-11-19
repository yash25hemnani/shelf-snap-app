import 'package:cloud_firestore/cloud_firestore.dart';

// Why someone reported a library; the names are what the rules accept
enum ReportReason {
  spam('Spam or advertising'),
  inappropriate('Offensive or adult content'),
  impersonation('Pretending to be someone else'),
  other('Something else');

  final String label;
  const ReportReason(this.label);
}

// A report on a public or unlisted library, at reports/{libraryId}_{uid}.
// Nobody can read these in the app; they're reviewed in the console.
class LibraryReport {
  final String libraryId;
  final String libraryName; // so the console shows which library
  final String reporterId;
  final ReportReason reason;
  final String? note;

  const LibraryReport({
    required this.libraryId,
    required this.libraryName,
    required this.reporterId,
    required this.reason,
    this.note,
  });

  // One report per person per library; reporting again replaces it
  String get id => '${libraryId}_$reporterId';

  Map<String, dynamic> toMap() => {
    'libraryId': libraryId,
    // The rules cap it at 100
    'libraryName': libraryName.length > 100
        ? libraryName.substring(0, 100)
        : libraryName,
    'reporterId': reporterId,
    'reason': reason.name,
    'note': note,
    // Must equal request.time in the rules
    'createdAt': FieldValue.serverTimestamp(),
  };
}
