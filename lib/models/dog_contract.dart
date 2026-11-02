import 'package:cloud_firestore/cloud_firestore.dart';

/// Yearly contract attached to a dog. Valid from the upload day through the
/// same calendar day one year later, inclusive.
class DogContract {
  final List<String> photoUrls;
  final DateTime uploadedAt;

  const DogContract({
    required this.photoUrls,
    required this.uploadedAt,
  });

  DateTime get expiresAt => DateTime(
        uploadedAt.year + 1,
        uploadedAt.month,
        uploadedAt.day,
      );

  bool isValidOn(DateTime date) {
    if (photoUrls.isEmpty) return false;
    final day = contractDateOnly(date);
    final start = contractDateOnly(uploadedAt);
    final end = contractDateOnly(expiresAt);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Still valid, and the end date falls before the same day next month.
  bool expiresInLessThanMonth(DateTime date) {
    if (!isValidOn(date)) return false;
    final day = contractDateOnly(date);
    final end = contractDateOnly(expiresAt);
    final monthLater = DateTime(day.year, day.month + 1, day.day);
    return end.isBefore(monthLater);
  }

  int daysRemainingOn(DateTime date) {
    return contractDateOnly(expiresAt).difference(contractDateOnly(date)).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrls': photoUrls,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  static DogContract? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final urls = (data['photoUrls'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final uploadedRaw = data['uploadedAt'];
    DateTime? uploadedAt;
    if (uploadedRaw is Timestamp) {
      uploadedAt = uploadedRaw.toDate();
    } else if (uploadedRaw is DateTime) {
      uploadedAt = uploadedRaw;
    }
    if (urls.isEmpty || uploadedAt == null) return null;
    return DogContract(photoUrls: urls, uploadedAt: uploadedAt);
  }
}

DateTime contractDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

enum DogContractAlert { none, missing, expiring }

String contractDaysRemainingLabel(int days) {
  if (days < 0) return 'פג תוקף';
  if (days == 0) return 'בתוקף עד היום';
  if (days == 1) return 'נותר יום אחד';
  if (days == 2) return 'נותרו יומיים';
  return 'נותרו $days ימים';
}
