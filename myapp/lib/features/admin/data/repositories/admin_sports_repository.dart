import '../../../../core/config/supabase_config.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../../sports/data/models/competition_model.dart';

class AdminSportsRepository {
  Future<List<SportModel>> getAllSports() async {
    final res = await SupabaseConfig.client
        .from('sports')
        .select()
        .order('display_order');
    return (res as List).map((j) => SportModel.fromJson(j)).toList();
  }

  Future<void> createSport(Map<String, dynamic> data) async {
    await SupabaseConfig.client.from('sports').insert(data);
  }
  Future<List<Map<String, dynamic>>> getAllProPlayersRaw({String search = ''}) async {
  var query = SupabaseConfig.client
      .from('players')
      .select('*, competitions(name)') // jointure pour afficher le nom de la compétition
      .eq('type', 'pro');

  if (search.trim().isNotEmpty) {
    query = query.ilike('full_name', '%${search.trim()}%');
  }

  final response = await query.order('full_name');
  return (response as List).cast<Map<String, dynamic>>();
}
  Future<void> updateSport(String id, Map<String, dynamic> data) async {
    await SupabaseConfig.client.from('sports').update(data).eq('id', id);
  }

  /// Supprime un sport ET ses compétitions -> joueurs.
  /// Plus de couche Team à traverser : un seul niveau à nettoyer avant les
  /// compétitions elles-mêmes (contrainte players.competition_id).
  Future<void> deleteSport(String id) async {
    final competitions = await SupabaseConfig.client
        .from('competitions')
        .select('id')
        .eq('sport_id', id);
    final competitionIds =
        (competitions as List).map((j) => j['id'] as String).toList();

    for (final competitionId in competitionIds) {
      await deleteCompetition(competitionId);
    }

    await SupabaseConfig.client.from('sports').delete().eq('id', id);
  }

  Future<List<CompetitionModel>> getCompetitionsForSport(String sportId) async {
    final res = await SupabaseConfig.client
        .from('competitions')
        .select()
        .eq('sport_id', sportId)
        .order('display_order');
    return (res as List).map((j) => CompetitionModel.fromJson(j)).toList();
  }

  Future<void> createCompetition(Map<String, dynamic> data) async {
    // Même logique d'auto-incrément de display_order qu'avant pour les ligues.
    if (data['display_order'] == null) {
      final existing = await SupabaseConfig.client
          .from('competitions')
          .select('display_order')
          .eq('sport_id', data['sport_id'])
          .order('display_order', ascending: false)
          .limit(1);
      final maxOrder = (existing as List).isNotEmpty
          ? (existing.first['display_order'] as int? ?? 0)
          : 0;
      data['display_order'] = maxOrder + 1;
    }
    await SupabaseConfig.client.from('competitions').insert(data);
  }

  Future<void> updateCompetition(String id, Map<String, dynamic> data) async {
    await SupabaseConfig.client
        .from('competitions')
        .update(data)
        .eq('id', id);
  }

  /// Supprime une compétition ET ses joueurs directement
  /// (players.competition_id -- plus de couche Team intermédiaire).
  Future<void> deleteCompetition(String id) async {
    await SupabaseConfig.client
        .from('players')
        .delete()
        .eq('competition_id', id);
    await SupabaseConfig.client.from('competitions').delete().eq('id', id);
  }
}