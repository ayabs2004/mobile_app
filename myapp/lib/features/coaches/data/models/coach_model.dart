class CoachTeamExperience {
  final String teamName;
  final int startYear;
  final int? endYear; // null = équipe actuelle

  const CoachTeamExperience({
    required this.teamName,
    required this.startYear,
    this.endYear,
  });

  bool get isCurrent => endYear == null;

  /// Durée en années (arrondie), utile pour l'affichage.
  int get durationYears {
    final end = endYear ?? DateTime.now().year;
    final d = end - startYear;
    return d < 0 ? 0 : d;
  }

 factory CoachTeamExperience.fromJson(Map<String, dynamic> json) {
  return CoachTeamExperience(
    teamName: json['team_name'] as String? ?? '',
    startYear: json['start_year'] as int? ?? DateTime.now().year,
    endYear: json['end_year'] as int?,
  );
}

  Map<String, dynamic> toJson() => {
        'team_name': teamName,
        'start_year': startYear,
        'end_year': endYear,
      };
}

class CoachModel {
  final String id;
  final String sportId;
  final String fullName;
  final String slug;
  final String? photoUrl;
  final String? biography;
  final int? yearsExperience;
  final List<String> certifications;
  final String? contactEmail;
  final bool isActive;
  final List<CoachTeamExperience> teamHistory;

  CoachModel({
    required this.id,
    required this.sportId,
    required this.fullName,
    required this.slug,
    this.photoUrl,
    this.biography,
    this.yearsExperience,
    this.certifications = const [],
    this.contactEmail,
    this.isActive = true,
    this.teamHistory = const [],
  });

  /// Équipe actuellement entraînée (s'il y en a une).
  CoachTeamExperience? get currentTeam {
    for (final t in teamHistory) {
      if (t.isCurrent) return t;
    }
    return null;
  }

  /// Équipes passées, triées de la plus récente à la plus ancienne.
  List<CoachTeamExperience> get pastTeams {
    final past = teamHistory.where((t) => !t.isCurrent).toList();
    past.sort((a, b) => b.startYear.compareTo(a.startYear));
    return past;
  }

  factory CoachModel.fromJson(Map<String, dynamic> json) => CoachModel(
        id: json['id'] as String,
        sportId: json['sport_id'] as String,
        fullName: json['full_name'] as String,
        slug: json['slug'] as String,
        photoUrl: json['photo_url'] as String?,
        biography: json['biography'] as String?,
        yearsExperience: json['years_experience'] as int?,
        certifications: (json['certifications'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        contactEmail: json['contact_email'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        teamHistory: () {
  final raw = json['team_history'];
  if (raw is! List) return <CoachTeamExperience>[];
  return raw
      .whereType<Map>()
      .map((e) => CoachTeamExperience.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}(),
      );

  Map<String, dynamic> toJson() => {
        'sport_id': sportId,
        'full_name': fullName,
        'slug': slug,
        'photo_url': photoUrl,
        'biography': biography,
        'years_experience': yearsExperience,
        'certifications': certifications,
        'contact_email': contactEmail,
        'is_active': isActive,
        'team_history': teamHistory.map((t) => t.toJson()).toList(),
      };
}