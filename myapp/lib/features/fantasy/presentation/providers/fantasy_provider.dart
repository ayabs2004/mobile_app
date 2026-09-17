import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../../data/models/fantasy_round_model.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../../data/models/fantasy_team_model.dart';

final fantasyRepositoryProvider = Provider<FantasyRepository>((ref) {
  return FantasyRepository();
});

final currentFantasyRoundProvider = FutureProvider.autoDispose
    .family<FantasyRoundModel?, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getCurrentRound(sportId);
});

/// `sportId` = null -> tous les joueurs fantasy (amateurs + pro).
/// `sportId` renseigné -> uniquement les joueurs de ce sport.
final fantasyPricedPlayersProvider = FutureProvider.autoDispose
    .family<List<FantasyPricedPlayer>, String?>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getPricedPlayers(sportId: sportId);
});

final myFantasyTeamProvider = FutureProvider.autoDispose
    .family<FantasyTeamModel?, String>((ref, roundId) {
  return ref.read(fantasyRepositoryProvider).getMyTeam(roundId);
});

final fantasyLeaderboardProvider = FutureProvider.autoDispose
    .family<List<FantasyLeaderboardEntry>, String>((ref, roundId) {
  return ref.read(fantasyRepositoryProvider).getLeaderboard(roundId);
});

/// Classement général (cumul sur tous les rounds) pour un sport donné.
final fantasyGeneralLeaderboardProvider = FutureProvider.autoDispose
    .family<List<FantasyGeneralLeaderboardEntry>, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getGeneralLeaderboard(sportId);
});

/// Notifier pour l'écran de composition d'équipe : gère la sélection
/// en cours (avant sauvegarde) + calcul du budget restant.
class FantasyTeamBuilderNotifier extends StateNotifier<Set<String>> {
  FantasyTeamBuilderNotifier() : super({});

  void toggle(String playerId) {
    if (state.contains(playerId)) {
      state = {...state}..remove(playerId);
    } else {
      state = {...state, playerId};
    }
  }

  void reset(List<String> playerIds) {
    state = playerIds.toSet();
  }
}

final fantasyTeamBuilderProvider =
    StateNotifierProvider.autoDispose<FantasyTeamBuilderNotifier, Set<String>>(
        (ref) {
  return FantasyTeamBuilderNotifier();
});

final fantasyCaptainProvider =
    StateProvider.autoDispose<String?>((ref) => null);