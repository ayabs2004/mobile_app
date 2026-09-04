class LicenseModel {
  final int id;
  final String status; // 'active' | 'inactive' | 'revoked'
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime updatedAt;

  const LicenseModel({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.updatedAt,
  });

  factory LicenseModel.fromMap(Map<String, dynamic> map) {
    return LicenseModel(
      id: map['id'] as int,
      status: map['status'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// true seulement si status == 'active' ET on est dans la fenetre started_at..expires_at
  bool get isValid {
    if (status != 'active') return false;

    final now = DateTime.now().toUtc();

    if (now.isBefore(startedAt.toUtc())) return false;
    if (now.isAfter(expiresAt.toUtc())) return false;

    return true;
  }
}
