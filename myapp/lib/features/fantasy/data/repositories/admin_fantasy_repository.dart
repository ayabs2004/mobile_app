import '../../../../core/config/supabase_config.dart';
import '../../../fantasy/data/models/fantasy_round_model.dart';
import '../../../fantasy/data/models/fantasy_player_pricing_model.dart';
import '../../../players/data/models/player_model.dart';

class AdminFantasyRepository {
  // ---------------- Rounds ----------------
  //
  // Les points fantasy ne sont plus attribués manuellement round par round :
  // ils sont calculés à partir des statistiques du joueur (déjà saisies et
  // scorées dans le formulaire joueur). Un round sert uniquement à ouvrir/
  // fermer une période de sélection d'équipe pour un sport donné (foot ou
  // hand) ; par défaut tous les joueurs (pro + amateur, hors académie) de
  // ce sport sont proposés aux utilisateurs.

  Future<List<FantasyRoundModel>> listRounds() async {
    final res = await SupabaseConfig.client
        .from('fantasy_rounds')
        .select()
        .order('created_at', ascending: false);

    return (res as List).map((j) => FantasyRoundModel.fromJson(j)).toList();
  }

  Future<FantasyRoundModel> createRound({
    required String name,
    required String sportId,
    double budget = 100.0,
    int maxPlayers = 11,
    int maxPerClub = 3,
  }) async {
    final res = await SupabaseConfig.client
        .from('fantasy_rounds')
        .insert({
          'name': name,
          'status': 'open',
          'budget': budget,
          'max_players': maxPlayers,
          'max_per_club': maxPerClub,
          'sport_id': sportId,
        })
        .select()
        .single();

    return FantasyRoundModel.fromJson(res);
  }

  Future<void> setRoundStatus(String roundId, String status) async {
    await SupabaseConfig.client
        .from('fantasy_rounds')
        .update({'status': status})
        .eq('id', roundId);
  }

  // ---------------- Pricing (coût des joueurs) ----------------

  /// Pricing fantasy existant pour UN joueur (null si jamais fixé).
  /// Utilisé pour préremplir le champ "Prix fantasy" dans le formulaire
  /// admin joueur (création/édition), sans passer par un écran dédié.
  Future<({double cost, bool isAvailable})?> getPricingForPlayer(
      String playerId) async {
    final res = await SupabaseConfig.client
        .from('fantasy_player_pricing')
        .select()
        .eq('player_id', playerId)
        .maybeSingle();

    if (res == null) return null;
    return (
      cost: (res['cost'] as num).toDouble(),
      isAvailable: res['is_available'] as bool? ?? true,
    );
  }

  /// Tous les joueurs actifs (amateurs et pro uniquement — le fantasy ne
  /// concerne jamais les joueurs académie) avec leur coût fantasy actuel
  /// (0 si pas encore fixé).
  Future<List<FantasyPricedPlayer>> listAllPlayersWithPricing() async {
    final playersRes = await SupabaseConfig.client
        .from('players_public')
        .select()
        .eq('is_active', true)
        .neq('type', 'academie')
        .order('full_name');

    final players =
        (playersRes as List).map((j) => PlayerModel.fromJson(j)).toList();
    if (players.isEmpty) return [];

    final pricingRes = await SupabaseConfig.client
        .from('fantasy_player_pricing')
        .select()
        .inFilter('player_id', players.map((p) => p.id).toList());

    final pricingByPlayer = <String, Map<String, dynamic>>{
      for (final row in (pricingRes as List))
        (row['player_id'] as String): row,
    };

    return players.map((p) {
      final pricing = pricingByPlayer[p.id];
      return FantasyPricedPlayer(
        player: p,
        cost: pricing != null ? (pricing['cost'] as num).toDouble() : 5.0,
        isAvailable: pricing != null ? pricing['is_available'] as bool : false,
      );
    }).toList();
  }

  Future<void> upsertPricing({
    required String playerId,
    required double cost,
    required bool isAvailable,
  }) async {
    await SupabaseConfig.client.from('fantasy_player_pricing').upsert({
      'player_id': playerId,
      'cost': cost,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
