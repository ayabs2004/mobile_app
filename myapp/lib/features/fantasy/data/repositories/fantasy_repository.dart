import '../../../../core/config/supabase_config.dart';
import '../../../players/data/models/player_model.dart';
import '../models/fantasy_sport_settings_model.dart';
import '../models/fantasy_player_pricing_model.dart';
import '../models/fantasy_team_model.dart';
import '../models/fantasy_score_snapshot_model.dart';

class FantasyRepository {
  /// Réglages fantasy (budget, effectif max, max par club) pour un sport.
  /// Remplace getCurrentRound : il n'y a plus de round, ces valeurs sont
  /// globales et permanentes par sport.
  Future<FantasySportSettingsModel> getSportSettings(String sportId) async {
    final res = await SupabaseConfig.client
        .from('fantasy_sport_settings')
        .select()
        .eq('sport_id', sportId)
        .maybeSingle();

    if (res == null) return FantasySportSettingsModel.defaults(sportId);
    return FantasySportSettingsModel.fromJson(res);
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

  /// Équipe courante de l'utilisateur pour un sport (null si pas encore
  /// composée). Il n'existe qu'une seule équipe par utilisateur et par
  /// sport : la composer à nouveau la remplace, pas de notion de round.
  Future<FantasyTeamModel?> getMyTeam(String sportId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return null;

    final teamRes = await SupabaseConfig.client
        .from('fantasy_teams')
        .select()
        .eq('user_id', userId)
        .eq('sport_id', sportId)
        .maybeSingle();

    if (teamRes == null) return null;

    final playersRes = await SupabaseConfig.client
        .from('fantasy_team_players')
        .select('player_id, slot_id')
        .eq('team_id', teamRes['id']);

    final rows = playersRes as List;
    final playerIds = rows.map((r) => r['player_id'] as String).toList();

    // Poste -> joueur, uniquement pour les lignes qui ont un slot_id
    // (schéma fixe) ; ignoré en mode libre.
    final slotAssignments = <String, String?>{
      for (final r in rows)
        if (r['slot_id'] != null) r['slot_id'] as String: r['player_id'] as String,
    };

    return FantasyTeamModel.fromJson(
      teamRes,
      playerIds: playerIds,
      slotAssignments: slotAssignments,
    );
  }

  /// Crée ou met à jour l'équipe de l'utilisateur pour un sport, puis
  /// capture un instantané (score + rang courants) dans l'historique —
  /// c'est ce qui permet d'afficher l'évolution du classement d'un essai
  /// à l'autre, sans notion de round.
  ///
  /// [formation] : clé du schéma tactique ('libre', '4-4-2'…), ou null.
  /// [slotAssignments] : poste -> joueur pour un schéma fixe (peut être
  /// vide en mode libre) ; sert uniquement à retrouver le poste de chaque
  /// joueur au moment de l'insertion.
  Future<void> saveTeam({
    required String sportId,
    required List<String> playerIds,
    String? captainPlayerId,
    String? formation,
    Map<String, String?> slotAssignments = const {},
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
            'sport_id': sportId,
            'captain_player_id': captainPlayerId,
            'formation': formation,
          },
          onConflict: 'user_id,sport_id',
        )
        .select()
        .single();

    final teamId = teamRes['id'] as String;

    // Joueur -> poste, pour retrouver rapidement le slot_id de chaque
    // joueur à insérer (inverse de slotAssignments).
    final slotByPlayer = <String, String>{
      for (final entry in slotAssignments.entries)
        if (entry.value != null) entry.value!: entry.key,
    };

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
                      'slot_id': slotByPlayer[playerId],
                    })
                .toList(),
          );
    }

    // Capture l'essai dans l'historique (score + rang à cet instant).
    // Doit être appelé après l'insert des joueurs pour que le calcul
    // côté SQL voie bien la composition à jour.
    await SupabaseConfig.client.rpc(
      'record_fantasy_score_snapshot',
      params: {'p_sport_id': sportId, 'p_team_id': teamId},
    );
  }

  /// Classement live d'un sport, trié par points décroissants.
  /// Passe par une fonction Postgres SECURITY DEFINER (get_fantasy_leaderboard)
  /// plutôt que par une vue, pour que l'élévation de privilège nécessaire
  /// à l'agrégation cross-utilisateurs soit explicite et auditable.
  ///
  /// Les points ne sont pas saisis manuellement : la fonction calcule
  /// directement le score de chaque joueur d'une équipe à partir de
  /// `player_statistics` (mêmes coefficients que
  /// `PlayerStatisticsModel.score` côté client), puis somme par
  /// utilisateur. Il n'y a plus qu'un seul classement par sport (pas de
  /// distinction round / général) : il varie en direct à chaque nouvel
  /// essai ou mise à jour des stats.
  Future<List<FantasyLeaderboardEntry>> getLeaderboard(String sportId) async {
    final res = await SupabaseConfig.client.rpc(
      'get_fantasy_leaderboard',
      params: {'p_sport_id': sportId},
    );

    return (res as List)
        .map((json) =>
            FantasyLeaderboardEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Historique des essais de l'utilisateur pour un sport : score et rang
  /// capturés à chaque sauvegarde d'équipe, triés chronologiquement.
  Future<List<FantasyScoreSnapshotModel>> getScoreHistory(
    String sportId,
  ) async {
    final res = await SupabaseConfig.client.rpc(
      'get_my_fantasy_score_history',
      params: {'p_sport_id': sportId},
    );

    return (res as List)
        .map((json) =>
            FantasyScoreSnapshotModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
