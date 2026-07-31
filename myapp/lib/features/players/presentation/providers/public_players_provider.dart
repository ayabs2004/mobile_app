import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/public_players_repository.dart';
import '../../data/models/player_with_stats_model.dart';
import '../../data/models/player_model.dart';

final publicPlayersRepositoryProvider =
    Provider<PublicPlayersRepository>((ref) {
  return PublicPlayersRepository();
});

final publicAmateurPlayersBySportProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, sportId) {
  return ref
      .read(publicPlayersRepositoryProvider)
      .getAmateurPlayersBySport(sportId);
});

final publicPlayersByCompetitionProvider =
    FutureProvider.family<List<PlayerWithDetails>, String>(
        (ref, competitionId) {
  return ref
      .read(publicPlayersRepositoryProvider)
      .getPlayersByCompetition(competitionId);
});

final publicPlayerDetailProvider =
    FutureProvider.family<PlayerWithDetails, String>((ref, playerId) {
  return ref.read(publicPlayersRepositoryProvider).getPlayerById(playerId);
});