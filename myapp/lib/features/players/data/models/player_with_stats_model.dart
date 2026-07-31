import 'player_model.dart';

class PlayerStatisticsModel {
  final int matchesPlayed;
  final int goals;
  final int assists;

  PlayerStatisticsModel({
    required this.matchesPlayed,
    required this.goals,
    required this.assists,
  });

  factory PlayerStatisticsModel.fromJson(Map<String, dynamic> json) {
    return PlayerStatisticsModel(
      matchesPlayed: json['matches_played'] as int? ?? 0,
      goals: json['goals'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
    );
  }
}

class PlayerWithDetails {
  final PlayerModel player;
  final String? teamName;
  final PlayerStatisticsModel? latestStats;

  PlayerWithDetails({
    required this.player,
    this.teamName,
    this.latestStats,
  });

  int? get age {
    if (player.dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - player.dateOfBirth!.year;
    if (now.month < player.dateOfBirth!.month ||
        (now.month == player.dateOfBirth!.month &&
            now.day < player.dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}