import 'package:flutter/foundation.dart';
import '../../../../core/config/supabase_config.dart';
import '../models/sport_model.dart';
import '../models/competition_model.dart';
import 'package:flutter/foundation.dart';
class SportsRepository {
  Future<List<SportModel>> getSports() async {
    final response = await SupabaseConfig.client
        .from('sports')
        .select()
        .eq('is_active', true)
        .order('display_order');

    return (response as List)
        .map((json) => SportModel.fromJson(json))
        .toList();
  }

  Future<List<CompetitionModel>> getCompetitionsForSport(String sportId) async {
  final response = await SupabaseConfig.client
      .from('competitions')
      .select()
      .eq('sport_id', sportId)
      .eq('is_active', true)
      .order('display_order');

  final list = (response as List)
      .map((json) => CompetitionModel.fromJson(json))
      .toList();

  debugPrint(
    'Compétitions reçues pour $sportId: ${list.map((c) => c.name).join(", ")}',
  );

  return list;
}

  /// Retourne {competitionId: nombre de joueurs} pour une liste de compétitions.
  Future<Map<String, int>> getCompetitionPlayerCounts(
      List<String> competitionIds) async {
    if (competitionIds.isEmpty) return {};

    final response = await SupabaseConfig.client
        .from('players')
        .select('id, competition_id')
        .inFilter('competition_id', competitionIds)
        .eq('is_active', true);

    final counts = <String, int>{};
    for (final row in (response as List)) {
      final competitionId = row['competition_id'] as String;
      counts[competitionId] = (counts[competitionId] ?? 0) + 1;
    }
    return counts;
  }
}