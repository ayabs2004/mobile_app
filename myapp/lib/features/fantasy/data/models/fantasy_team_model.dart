class FantasyTeamModel {
  final String? id;
  final String userId;
  final String sportId;
  final String? captainPlayerId;
  final List<String> playerIds;

  /// Schéma tactique sauvegardé ('libre', '4-4-2', '4-3-3'…), ou null pour
  /// les équipes enregistrées avant l'introduction des schémas fixes.
  final String? formation;

  /// Poste (slot id, ex: 'DEF_1') -> joueur placé sur ce poste, pour un
  /// schéma fixe. Vide en mode libre ou pour les anciennes équipes.
  final Map<String, String?> slotAssignments;

  FantasyTeamModel({
    this.id,
    required this.userId,
    required this.sportId,
    this.captainPlayerId,
    required this.playerIds,
    this.formation,
    this.slotAssignments = const {},
  });

  factory FantasyTeamModel.fromJson(
    Map<String, dynamic> json, {
    List<String> playerIds = const [],
    Map<String, String?> slotAssignments = const {},
  }) {
    return FantasyTeamModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      sportId: json['sport_id'] as String,
      captainPlayerId: json['captain_player_id'] as String?,
      playerIds: playerIds,
      formation: json['formation'] as String?,
      slotAssignments: slotAssignments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'sport_id': sportId,
      'captain_player_id': captainPlayerId,
      'formation': formation,
    };
  }
}

class FantasyLeaderboardEntry {
  final String userId;
  final String userName;
  final int totalPoints;

  FantasyLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.totalPoints,
  });

  factory FantasyLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return FantasyLeaderboardEntry(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Utilisateur',
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
    );
  }
}

