import '../../../../core/config/supabase_config.dart';
import '../../../players/data/models/player_model.dart';

class CompetitionOption {
  final String id;
  final String name;
  const CompetitionOption({required this.id, required this.name});

  factory CompetitionOption.fromJson(Map<String, dynamic> json) {
    return CompetitionOption(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class AdminPlayersRepository {
  /// Joueurs PRO, filtrés optionnellement par sport (via la compétition).
  Future<List<PlayerModel>> getPlayersBySport(
    String? sportId, {
    String search = '',
  }) async {
    var query = SupabaseConfig.client
        .from('players')
        .select('*, competitions!inner(sport_id)')
        .eq('type', 'pro');

    if (sportId != null) {
      query = query.eq('competitions.sport_id', sportId);
    }
    if (search.trim().isNotEmpty) {
      query = query.ilike('full_name', '%${search.trim()}%');
    }

    final response = await query.order('full_name');
    return (response as List).map((json) => PlayerModel.fromJson(json)).toList();
  }

  /// Joueurs AMATEURS, filtrés optionnellement par sport (colonne directe).
  Future<List<PlayerModel>> getAmateurPlayers({
    String search = '',
    String? sportId,
  }) async {
    var query = SupabaseConfig.client
        .from('players')
        .select()
        .eq('type', 'amateur');

    if (sportId != null) {
      query = query.eq('sport_id', sportId);
    }
    if (search.trim().isNotEmpty) {
      query = query.ilike('full_name', '%${search.trim()}%');
    }

    final response = await query.order('full_name');
    return (response as List).map((json) => PlayerModel.fromJson(json)).toList();
  }

  Future<List<CompetitionOption>> getAllCompetitions() async {
    final response = await SupabaseConfig.client
        .from('competitions')
        .select('id, name')
        .order('name');

    return (response as List).map((json) => CompetitionOption.fromJson(json)).toList();
  }

  Future<void> createPlayer(PlayerModel player) async {
    await SupabaseConfig.client.from('players').insert(player.toJson());
  }

  Future<void> updatePlayer(String id, PlayerModel player) async {
    await SupabaseConfig.client.from('players').update(player.toJson()).eq('id', id);
  }

  Future<void> deletePlayer(String id) async {
    await SupabaseConfig.client.from('players').delete().eq('id', id);
  }
}