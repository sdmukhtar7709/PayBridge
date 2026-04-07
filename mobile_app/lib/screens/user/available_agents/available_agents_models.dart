part of 'available_agents_screen.dart';

class _RequestState {
  final String transactionId;
  final String status;
  final int amount;
  final int agentCommission;
  final int totalPaid;
  final int agentReceived;
  final String requestOtp;
  final String userConfirmOtp;
  final DateTime? approvedAt;
  final DateTime? userConfirmedAt;
  final DateTime? agentConfirmedAt;
  final bool rejectionNotified;
  final bool approvedNotified;

  const _RequestState({
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.agentCommission,
    required this.totalPaid,
    required this.agentReceived,
    this.requestOtp = '',
    this.userConfirmOtp = '',
    this.approvedAt,
    this.userConfirmedAt,
    this.agentConfirmedAt,
    this.rejectionNotified = false,
    this.approvedNotified = false,
  });

  _RequestState copyWith({
    String? transactionId,
    String? status,
    int? amount,
    int? agentCommission,
    int? totalPaid,
    int? agentReceived,
    String? requestOtp,
    String? userConfirmOtp,
    DateTime? approvedAt,
    DateTime? userConfirmedAt,
    DateTime? agentConfirmedAt,
    bool? rejectionNotified,
    bool? approvedNotified,
  }) {
    return _RequestState(
      transactionId: transactionId ?? this.transactionId,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      agentCommission: agentCommission ?? this.agentCommission,
      totalPaid: totalPaid ?? this.totalPaid,
      agentReceived: agentReceived ?? this.agentReceived,
      requestOtp: requestOtp ?? this.requestOtp,
      userConfirmOtp: userConfirmOtp ?? this.userConfirmOtp,
      approvedAt: approvedAt ?? this.approvedAt,
      userConfirmedAt: userConfirmedAt ?? this.userConfirmedAt,
      agentConfirmedAt: agentConfirmedAt ?? this.agentConfirmedAt,
      rejectionNotified: rejectionNotified ?? this.rejectionNotified,
      approvedNotified: approvedNotified ?? this.approvedNotified,
    );
  }
}

class _AgentSummary {
  final String id;
  final String name;
  final String locationName;
  final String city;
  final String address;
  final String email;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final bool available;
  final bool isBanned;
  final int ratingSum;
  final int ratingCount;
  final double? distanceKm;
  final Uint8List? profilePhotoBytes;

  const _AgentSummary({
    required this.id,
    required this.name,
    required this.locationName,
    required this.city,
    required this.address,
    required this.email,
    required this.phone,
    this.latitude,
    this.longitude,
    required this.isVerified,
    required this.available,
    required this.isBanned,
    required this.ratingSum,
    required this.ratingCount,
    this.distanceKm,
    this.profilePhotoBytes,
  });

  double? get averageRating {
    if (ratingCount <= 0) return null;
    return ratingSum / ratingCount;
  }

  _AgentSummary copyWith({
    int? ratingSum,
    int? ratingCount,
    double? distanceKm,
  }) {
    return _AgentSummary(
      id: id,
      name: name,
      locationName: locationName,
      city: city,
      address: address,
      email: email,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      isVerified: isVerified,
      available: available,
      isBanned: isBanned,
      ratingSum: ratingSum ?? this.ratingSum,
      ratingCount: ratingCount ?? this.ratingCount,
      distanceKm: distanceKm,
      profilePhotoBytes: profilePhotoBytes,
    );
  }

  factory _AgentSummary.fromJson(Map<String, dynamic> json) {
    // Agent profile has a nested `user` object for name
    final user = json['user'] is Map<String, dynamic>
      ? json['user'] as Map<String, dynamic>
      : <String, dynamic>{};
    final name = _asString(user['name']).isNotEmpty
      ? _asString(user['name'])
      : (_asString(json['name']).isNotEmpty ? _asString(json['name']) : 'Unknown Agent');

    final locationName = _asString(json['locationName']);
    final city = _asString(json['city']).trim();
    final address = _asString(user['address']).trim();
    final email = _asString(user['email']).trim();
    final phone = _asString(user['phone']).trim();
    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);
    final isVerified = (json['isVerified'] as bool?) ?? false;
    final available = (json['available'] as bool?) ?? false;
    final isBanned = (json['isBanned'] as bool?) ?? false;
    final ratingSum = int.tryParse((json['ratingSum'] ?? '0').toString()) ?? 0;
    final ratingCount = int.tryParse((json['ratingCount'] ?? '0').toString()) ?? 0;
    final distanceKm = _toDouble(json['distanceKm']);

    // Profile photo
    final rawPhoto = _asString(user['profileImage']).isNotEmpty
      ? _asString(user['profileImage'])
      : _asString(json['profileImage']);
    Uint8List? photoBytes;
    if (rawPhoto.trim().isNotEmpty) {
      final trimmed = rawPhoto.trim();
      final base64str = trimmed.startsWith('data:image') && trimmed.contains(',')
          ? trimmed.substring(trimmed.indexOf(',') + 1)
          : trimmed;
      try {
        photoBytes = base64Decode(base64str);
      } catch (_) {}
    }

    return _AgentSummary(
      id: json['id']?.toString() ?? '',
      name: name,
      locationName: locationName,
      city: city,
      address: address,
      email: email,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      isVerified: isVerified,
      available: available,
      isBanned: isBanned,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      distanceKm: distanceKm,
      profilePhotoBytes: photoBytes,
    );
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
