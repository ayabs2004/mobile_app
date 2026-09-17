import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_fantasy_repository.dart';
import '../../../fantasy/data/models/fantasy_round_model.dart';
import '../../../fantasy/data/models/fantasy_player_pricing_model.dart';

final adminFantasyRepositoryProvider = Provider<AdminFantasyRepository>((ref) {
  return AdminFantasyRepository();
});

final adminFantasyRoundsProvider =
    FutureProvider.autoDispose<List<FantasyRoundModel>>((ref) {
  return ref.read(adminFantasyRepositoryProvider).listRounds();
});

final adminFantasyPricingProvider =
    FutureProvider.autoDispose<List<FantasyPricedPlayer>>((ref) {
  return ref.read(adminFantasyRepositoryProvider).listAllPlayersWithPricing();
});
