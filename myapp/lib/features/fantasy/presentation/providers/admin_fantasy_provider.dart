import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_fantasy_repository.dart';
import '../../../fantasy/data/models/fantasy_sport_settings_model.dart';
import '../../../fantasy/data/models/fantasy_player_pricing_model.dart';

final adminFantasyRepositoryProvider = Provider<AdminFantasyRepository>((ref) {
  return AdminFantasyRepository();
});

/// Réglages fantasy (budget, effectif max, max par club) pour un sport,
/// éditables par l'admin. Remplace adminFantasyRoundsProvider.
final adminFantasySportSettingsProvider = FutureProvider.autoDispose
    .family<FantasySportSettingsModel, String>((ref, sportId) {
  return ref.read(adminFantasyRepositoryProvider).getSportSettings(sportId);
});

final adminFantasyPricingProvider =
    FutureProvider.autoDispose<List<FantasyPricedPlayer>>((ref) {
  return ref.read(adminFantasyRepositoryProvider).listAllPlayersWithPricing();
});
