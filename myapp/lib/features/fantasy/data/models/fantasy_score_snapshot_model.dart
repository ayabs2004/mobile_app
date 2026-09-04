/// Un instantané du score/rang de l'utilisateur, capturé à chaque
/// sauvegarde d'équipe. Permet d'afficher l'évolution de son classement
/// au fil de ses essais, sans notion de round.
class FantasyScoreSnapshotModel {
  final String id;
  final String userId;
  final String sportId;
  final String? teamId;
  final int totalPoints;
  final int rank;
  final DateTime createdAt;

  const FantasyScoreSnapshotModel({
    required this.id,
    required this.userId,
    required this.sportId,
    this.teamId,
    required this.totalPoints,
    required this.rank,
    required this.createdAt,
  });

  factory FantasyScoreSnapshotModel.fromJson(Map<String, dynamic> json) {
    return FantasyScoreSnapshotModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sportId: json['sport_id'] as String,
      teamId: json['team_id'] as String?,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
