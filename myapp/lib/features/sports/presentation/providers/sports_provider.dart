import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sport_model.dart';
import '../../data/models/competition_model.dart';
import '../../data/repositories/sports_repository.dart';

final sportsRepositoryProvider = Provider<SportsRepository>((ref) {
  return SportsRepository();
});

final sportsListProvider = FutureProvider<List<SportModel>>((ref) {
  return ref.read(sportsRepositoryProvider).getSports();
});

final competitionsBySportProvider =
    FutureProvider.family<List<CompetitionModel>, String>((ref, sportId) {
  return ref.read(sportsRepositoryProvider).getCompetitionsForSport(sportId);
});

/// Clé = liste d'ids séparés par des virgules, comme avant avec leagueStatsProvider.
final competitionPlayerCountsProvider =
    FutureProvider.family<Map<String, int>, String>(
        (ref, competitionIdsKey) {
  final ids =
      competitionIdsKey.split(',').where((s) => s.isNotEmpty).toList();
  return ref.read(sportsRepositoryProvider).getCompetitionPlayerCounts(ids);
});