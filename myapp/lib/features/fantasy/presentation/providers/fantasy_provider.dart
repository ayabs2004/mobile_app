import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/fantasy_formation.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../../data/models/fantasy_sport_settings_model.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../../data/models/fantasy_team_model.dart';
import '../../data/models/fantasy_score_snapshot_model.dart';

final fantasyRepositoryProvider = Provider<FantasyRepository>((ref) {
  return FantasyRepository();
});

/// Réglages fantasy (budget, effectif max, max par club) pour un sport.
/// Remplace currentFantasyRoundProvider.
final fantasySportSettingsProvider = FutureProvider.autoDispose
    .family<FantasySportSettingsModel, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getSportSettings(sportId);
});

/// `sportId` = null -> tous les joueurs fantasy (amateurs + pro).
/// `sportId` renseigné -> uniquement les joueurs de ce sport.
final fantasyPricedPlayersProvider = FutureProvider.autoDispose
    .family<List<FantasyPricedPlayer>, String?>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getPricedPlayers(sportId: sportId);
});

/// Équipe courante de l'utilisateur pour un sport (une seule par sport,
/// modifiable à tout moment : plus de round).
final myFantasyTeamProvider = FutureProvider.autoDispose
    .family<FantasyTeamModel?, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getMyTeam(sportId);
});

/// Classement live d'un sport (recalculé à chaque lecture).
final fantasyLeaderboardProvider = FutureProvider.autoDispose
    .family<List<FantasyLeaderboardEntry>, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getLeaderboard(sportId);
});

/// Historique des essais de l'utilisateur pour un sport (score + rang à
/// chaque sauvegarde d'équipe), trié chronologiquement.
final fantasyScoreHistoryProvider = FutureProvider.autoDispose
    .family<List<FantasyScoreSnapshotModel>, String>((ref, sportId) {
  return ref.read(fantasyRepositoryProvider).getScoreHistory(sportId);
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

/// Schéma tactique choisi pour la composition ('libre' par défaut, ou la clé
/// d'un `FormationTemplate` comme '4-4-2').
final fantasyFormationProvider =
    StateProvider.autoDispose<String>((ref) => kFreeFormationKey);

/// Pour un schéma fixe : affectation poste -> joueur (id) choisi.
/// Garde la correspondance entre chaque rond du terrain et le joueur qui y
/// est placé, pour savoir quel poste modifier/vider.
class FantasyFormationSlotsNotifier extends StateNotifier<Map<String, String?>> {
  FantasyFormationSlotsNotifier() : super({});

  /// Réinitialise les postes pour un nouveau schéma (tous vides).
  void resetForTemplate(FormationTemplate template) {
    state = {for (final s in template.slots) s.id: null};
  }

  /// Restaure les postes tels que sauvegardés (ex: équipe déjà enregistrée
  /// avec un schéma fixe), sans passer par un `FormationTemplate` puisque
  /// les ids de postes sont déjà connus.
  void restore(Map<String, String?> slotAssignments) {
    state = {...slotAssignments};
  }

  void clear() => state = {};

  void assign(String slotId, String playerId) {
    state = {...state, slotId: playerId};
  }

  void clearSlot(String slotId) {
    state = {...state, slotId: null};
  }

  /// Vide le poste qui contient ce joueur, s'il existe.
  void clearPlayer(String playerId) {
    final entry = state.entries.where((e) => e.value == playerId).firstOrNull;
    if (entry != null) {
      state = {...state, entry.key: null};
    }
  }
}

final fantasyFormationSlotsProvider = StateNotifierProvider.autoDispose<
    FantasyFormationSlotsNotifier, Map<String, String?>>((ref) {
  return FantasyFormationSlotsNotifier();
});

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
