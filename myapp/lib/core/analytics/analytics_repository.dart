import '../config/supabase_config.dart';

/// Utilisé dans toute l'app pour enregistrer les événements qui alimentent
/// le dashboard admin (visites, joueurs les plus consultés, etc.).
///
/// Le tracking ne doit jamais faire échouer ni ralentir l'expérience
/// utilisateur : toute erreur d'insertion est volontairement avalée.
class AnalyticsRepository {
  Future<void> logEvent({
    required String eventType,
    String? entityType,
    String? entityId,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    try {
      await SupabaseConfig.client.from('analytics_events').insert({
        'event_type': eventType,
        'entity_type': entityType,
        'entity_id': entityId,
        'user_id': userId,
      });
    } catch (_) {
      // On ignore silencieusement une erreur de tracking —
      // ça ne doit jamais bloquer l'utilisation normale de l'app.
    }
  }
}
