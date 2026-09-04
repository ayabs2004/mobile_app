/// Paramètres fantasy pour un sport donné (foot ou hand).
/// Remplace FantasyRoundModel : il n'y a plus de round, seulement des
/// réglages globaux (budget, effectif max, max par club) par sport.
class FantasySportSettingsModel {
  final String sportId;
  final double budget;
  final int maxPlayers;
  final int maxPerClub;

  const FantasySportSettingsModel({
    required this.sportId,
    required this.budget,
    required this.maxPlayers,
    required this.maxPerClub,
  });

  factory FantasySportSettingsModel.fromJson(Map<String, dynamic> json) {
    return FantasySportSettingsModel(
      sportId: json['sport_id'] as String,
      budget: (json['budget'] as num?)?.toDouble() ?? 100.0,
      maxPlayers: json['max_players'] as int? ?? 11,
      maxPerClub: json['max_per_club'] as int? ?? 3,
    );
  }

  /// Valeurs par défaut si aucun réglage n'a encore été créé pour ce sport.
  factory FantasySportSettingsModel.defaults(String sportId) {
    return FantasySportSettingsModel(
      sportId: sportId,
      budget: 100.0,
      maxPlayers: 11,
      maxPerClub: 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sport_id': sportId,
      'budget': budget,
      'max_players': maxPlayers,
      'max_per_club': maxPerClub,
    };
  }
}
