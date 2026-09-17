import 'player_model.dart';

class PlayerStatisticsModel {
  final int matchesPlayed;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final int minutesPlayed;

  PlayerStatisticsModel({
    required this.matchesPlayed,
    required this.goals,
    required this.assists,
    this.yellowCards = 0,
    this.redCards = 0,
    this.minutesPlayed = 0,
  });

  factory PlayerStatisticsModel.fromJson(Map<String, dynamic> json) {
    return PlayerStatisticsModel(
      matchesPlayed: json['matches_played'] as int? ?? 0,
      goals: json['goals'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      yellowCards: json['yellow_cards'] as int? ?? 0,
      redCards: json['red_cards'] as int? ?? 0,
      minutesPlayed: json['minutes_played'] as int? ?? 0,
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Calcul du score du joueur.
  // Coefficients centralisés ici : à ajuster librement selon le
  // barème souhaité, sans toucher au reste de l'app.
  // ───────────────────────────────────────────────────────────────
  static const double _goalWeight = 4;
  static const double _assistWeight = 2;
  static const double _matchWeight = 0.5;
  static const double _minutesWeight = 0.2; // par tranche de 90 min
  static const double _yellowCardWeight = -1;
  static const double _redCardWeight = -3;

  double get score {
    final raw = (goals * _goalWeight) +
        (assists * _assistWeight) +
        (matchesPlayed * _matchWeight) +
        ((minutesPlayed / 90.0) * _minutesWeight) +
        (yellowCards * _yellowCardWeight) +
        (redCards * _redCardWeight);
    return raw < 0 ? 0 : raw;
  }

  /// Score arrondi à une décimale, prêt pour l'affichage.
  String get scoreDisplay => score.toStringAsFixed(1);
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