import '../../../../core/config/supabase_config.dart';
import '../../../players/data/models/player_model.dart';
import '../models/fantasy_round_model.dart';
import '../models/fantasy_player_pricing_model.dart';
import '../models/fantasy_team_model.dart';

class FantasyRepository {
  /// Round actif (le plus récent avec status = 'open') pour un sport donné.
  /// Le fantasy n'existe que pour le foot et le hand : chaque round est
  /// rattaché à un seul sport.
  Future<FantasyRoundModel?> getCurrentRound(String sportId) async {
    final res = await SupabaseConfig.client
        .from('fantasy_rounds')
        .select()
        .eq('status', 'open')
        .eq('sport_id', sportId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return FantasyRoundModel.fromJson(res);
  }

  /// Liste des joueurs disponibles avec leur coût fantasy.
  /// (2 requêtes + combinaison en Dart, même pattern que
  /// PublicPlayersRepository.getPlayersByCompetition)
  ///
  /// Le fantasy ne concerne que les joueurs amateurs et pro (jamais les
  /// joueurs académie). Si [sportId] est fourni, seuls les joueurs de ce
  /// sport sont retournés : directement via `sport_id` pour les amateurs,
  /// via le sport de leur compétition pour les pro.
  Future<List<FantasyPricedPlayer>> getPricedPlayers({String? sportId}) async {
    final pricingRes = await SupabaseConfig.client
        .from('fantasy_player_pricing')
        .select()
        .eq('is_available', true);

    final pricingRows = pricingRes as List;
    if (pricingRows.isEmpty) return [];

    final playerIds = pricingRows.map((r) => r['player_id'] as String).toList();

    final playersRes = await SupabaseConfig.client
        .from('players_public')
        .select()
        .inFilter('id', playerIds)
        .eq('is_active', true)
        .neq('type', 'academie');

    var players =
        (playersRes as List).map((j) => PlayerModel.fromJson(j)).toList();

    if (sportId != null) {
      final competitionsRes = await SupabaseConfig.client
          .from('competitions')
          .select('id')
          .eq('sport_id', sportId);
      final competitionIds =
          (competitionsRes as List).map((r) => r['id'] as String).toSet();

      players = players.where((p) {
        if (p.type == 'amateur') return p.sportId == sportId;
        // pro : rattaché via sa compétition, pas directement via sport_id.
        return p.competitionId != null &&
            competitionIds.contains(p.competitionId);
      }).toList();
    }

    final playersById = <String, PlayerModel>{
      for (final p in players) p.id: p,
    };

    return pricingRows
        .where((row) => playersById.containsKey(row['player_id']))
        .map((row) => FantasyPricedPlayer(
              player: playersById[row['player_id']]!,
              cost: (row['cost'] as num).toDouble(),
              isAvailable: row['is_available'] as bool? ?? true,
            ))
        .toList();
  }

  /// Équipe de l'utilisateur pour un round donné (null si pas encore créée).
  Future<FantasyTeamModel?> getMyTeam(String roundId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return null;

    final teamRes = await SupabaseConfig.client
        .from('fantasy_teams')
        .select()
        .eq('user_id', userId)
        .eq('round_id', roundId)
        .maybeSingle();

    if (teamRes == null) return null;

    final playersRes = await SupabaseConfig.client
        .from('fantasy_team_players')
        .select('player_id')
        .eq('team_id', teamRes['id']);

    final playerIds =
        (playersRes as List).map((r) => r['player_id'] as String).toList();

    return FantasyTeamModel.fromJson(teamRes, playerIds: playerIds);
  }

  /// Crée ou met à jour l'équipe de l'utilisateur pour un round.
  /// (upsert du "header" puis remplacement complet des joueurs)
  Future<void> saveTeam({
    required String roundId,
    required List<String> playerIds,
    String? captainPlayerId,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final teamRes = await SupabaseConfig.client
        .from('fantasy_teams')
        .upsert(
          {
            'user_id': userId,
            'round_id': roundId,
            'captain_player_id': captainPlayerId,
          },
          onConflict: 'user_id,round_id',
        )
        .select()
        .single();

    final teamId = teamRes['id'] as String;

    // Remplace la sélection complète (simple pour une V0)
    await SupabaseConfig.client
        .from('fantasy_team_players')
        .delete()
        .eq('team_id', teamId);

    if (playerIds.isNotEmpty) {
      await SupabaseConfig.client.from('fantasy_team_players').insert(
            playerIds
                .map((playerId) => {
                      'team_id': teamId,
                      'player_id': playerId,
                    })
                .toList(),
          );
    }
  }

  /// Classement pour un round, trié par points décroissants.
  /// Passe par une fonction Postgres SECURITY DEFINER (get_fantasy_leaderboard)
  /// plutôt que par une vue, pour que l'élévation de privilège nécessaire
  /// à l'agrégation cross-utilisateurs soit explicite et auditable.
  ///
  /// Les points ne sont plus saisis manuellement round par round : la
  /// fonction calcule directement le score de chaque joueur d'une équipe
  /// à partir de `player_statistics` (mêmes coefficients que
  /// `PlayerStatisticsModel.score` côté client), puis somme par
  /// utilisateur. Voir la migration SQL fournie côté backend.
  Future<List<FantasyLeaderboardEntry>> getLeaderboard(String roundId) async {
    final res = await SupabaseConfig.client.rpc(
      'get_fantasy_leaderboard',
      params: {'p_round_id': roundId},
    );

    return (res as List)
        .map((json) =>
            FantasyLeaderboardEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Classement général pour un sport : cumul des points de chaque
  /// utilisateur sur tous ses rounds (clos ou en cours) de ce sport.
  /// Passe par la RPC `get_fantasy_leaderboard_general` (même logique
  /// SECURITY DEFINER que le classement par round).
  Future<List<FantasyGeneralLeaderboardEntry>> getGeneralLeaderboard(
    String sportId,
  ) async {
    final res = await SupabaseConfig.client.rpc(
      'get_fantasy_leaderboard_general',
      params: {'p_sport_id': sportId},
    );

    return (res as List)
        .map((json) => FantasyGeneralLeaderboardEntry.fromJson(
            json as Map<String, dynamic>))
        .toList();
  }
}