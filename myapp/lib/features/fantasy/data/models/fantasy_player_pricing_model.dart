import '../../../players/data/models/player_model.dart';

/// Combine un PlayerModel existant avec son coût fantasy.
class FantasyPricedPlayer {
  final PlayerModel player;
  final double cost;
  final bool isAvailable;

  FantasyPricedPlayer({
    required this.player,
    required this.cost,
    required this.isAvailable,
  });
}