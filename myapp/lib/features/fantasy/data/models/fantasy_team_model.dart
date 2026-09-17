class FantasyTeamModel {
  final String? id;
  final String userId;
  final String roundId;
  final String? captainPlayerId;
  final List<String> playerIds;

  FantasyTeamModel({
    this.id,
    required this.userId,
    required this.roundId,
    this.captainPlayerId,
    required this.playerIds,
  });

  factory FantasyTeamModel.fromJson(
    Map<String, dynamic> json, {
    List<String> playerIds = const [],
  }) {
    return FantasyTeamModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      roundId: json['round_id'] as String,
      captainPlayerId: json['captain_player_id'] as String?,
      playerIds: playerIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'round_id': roundId,
      'captain_player_id': captainPlayerId,
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

/// Ligne du classement général (cumul de tous les rounds d'un sport),
/// retournée par la RPC `get_fantasy_leaderboard_general`.
class FantasyGeneralLeaderboardEntry {
  final String userId;
  final String userName;
  final int roundsPlayed;
  final int totalPoints;

  FantasyGeneralLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.roundsPlayed,
    required this.totalPoints,
  });

  factory FantasyGeneralLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return FantasyGeneralLeaderboardEntry(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Utilisateur',
      roundsPlayed: (json['rounds_played'] as num?)?.toInt() ?? 0,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
    );
  }
}