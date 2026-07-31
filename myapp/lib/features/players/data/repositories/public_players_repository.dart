import '../../../../core/config/supabase_config.dart';
import '../../../../core/analytics/analytics_repository.dart';
import '../models/player_model.dart';
import '../models/player_with_stats_model.dart';

class PublicPlayersRepository {
  final AnalyticsRepository _analytics = AnalyticsRepository();

  Future<List<PlayerWithDetails>> getPlayersByCompetition(
      String competitionId) async {
    // Plus de jointure teams -> players : la FK est directe.
    final playersResponse = await SupabaseConfig.client
        .from('players')
        .select()
        .eq('competition_id', competitionId)
        .eq('is_active', true)
        .order('full_name');

    final players = (playersResponse as List)
        .map((json) => PlayerModel.fromJson(json))
        .toList();

    if (players.isEmpty) return [];

    final playerIds = players.map((p) => p.id).toList();
    final statsResponse = await SupabaseConfig.client
        .from('player_statistics')
        .select()
        .inFilter('player_id', playerIds)
        .order('season', ascending: false);

    final statsByPlayer = <String, PlayerStatisticsModel>{};
    for (final row in (statsResponse as List)) {
      final playerId = row['player_id'] as String;
      statsByPlayer.putIfAbsent(
          playerId, () => PlayerStatisticsModel.fromJson(row));
    }

    return players
        .map((p) => PlayerWithDetails(
              player: p,
              teamName: p.teamName, // vient directement de la colonne
              latestStats: statsByPlayer[p.id],
            ))
        .toList();
  }

  Future<PlayerWithDetails> getPlayerById(String playerId) async {
    final playerResponse = await SupabaseConfig.client
        .from('players')
        .select()
        .eq('id', playerId)
        .single();

    final player = PlayerModel.fromJson(playerResponse);

    // ignore: unawaited_futures
    _analytics.logEvent(
      eventType: 'view_player',
      entityType: 'player',
      entityId: playerId,
    );

    final statsResponse = await SupabaseConfig.client
        .from('player_statistics')
        .select()
        .eq('player_id', playerId)
        .order('season', ascending: false)
        .limit(1)
        .maybeSingle();

    final latestStats = statsResponse != null
        ? PlayerStatisticsModel.fromJson(statsResponse)
        : null;

    return PlayerWithDetails(
      player: player,
      teamName: player.teamName,
      latestStats: latestStats,
    );
  }
  Future<List<PlayerModel>> getAmateurPlayersBySport(String sportId) async {
  final res = await SupabaseConfig.client
      .from('players')
      .select()
      .eq('sport_id', sportId)
      .eq('type', 'amateur')
      .eq('is_active', true)
      .order('full_name');
  return (res as List).map((j) => PlayerModel.fromJson(j)).toList();
}
}