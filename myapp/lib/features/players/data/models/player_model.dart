class PlayerModel {
  final String id;
  final String? competitionId; // pro uniquement
  final String? sportId; // amateur uniquement
  final String type; // 'pro' | 'amateur'
  final String? teamName;
  final String fullName;
  final String slug;
  final String? position;
  final int? jerseyNumber;
  final String? nationality;
  final String? profileImageUrl;
  final String? coverImageUrl;
  final String? biography;
  final int? heightCm;
  final int? weightKg;
  final bool isActive;
  final DateTime? dateOfBirth;

  PlayerModel({
    required this.id,
    this.competitionId,
    this.sportId,
    required this.type,
    this.teamName,
    required this.fullName,
    required this.slug,
    this.position,
    this.jerseyNumber,
    this.nationality,
    this.profileImageUrl,
    this.coverImageUrl,
    this.biography,
    this.heightCm,
    this.weightKg,
    this.isActive = true,
    this.dateOfBirth,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String?,
      sportId: json['sport_id'] as String?,
      type: json['type'] as String? ?? 'pro',
      teamName: json['team_name'] as String?,
      fullName: json['full_name'] as String,
      slug: json['slug'] as String,
      position: json['position'] as String?,
      jerseyNumber: json['jersey_number'] as int?,
      nationality: json['nationality'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      biography: json['biography'] as String?,
      heightCm: json['height_cm'] as int?,
      weightKg: json['weight_kg'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'competition_id': competitionId,
      'sport_id': sportId,
      'type': type,
      'team_name': teamName,
      'full_name': fullName,
      'slug': slug,
      'position': position,
      'jersey_number': jerseyNumber,
      'nationality': nationality,
      'profile_image_url': profileImageUrl,
      'cover_image_url': coverImageUrl,
      'biography': biography,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'is_active': isActive,
    };
  }
}