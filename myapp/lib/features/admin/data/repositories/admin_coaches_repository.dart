import '../../../../core/config/supabase_config.dart';
import '../../../coaches/data/models/coach_model.dart';
import '../../../players/data/models/player_model.dart';

class AdminCoachesRepository {
  Future<List<CoachModel>> getAllCoaches() async {
    final res =
        await SupabaseConfig.client.from('coaches').select().order('full_name');
    return (res as List).map((j) => CoachModel.fromJson(j)).toList();
  }

  Future<List<CoachModel>> getCoachesBySport(String sportId) async {
    final res = await SupabaseConfig.client
        .from('coaches')
        .select()
        .eq('sport_id', sportId)
        .order('full_name');
    return (res as List).map((j) => CoachModel.fromJson(j)).toList();
  }

  Future<void> createCoach(CoachModel coach) async {
    await SupabaseConfig.client.from('coaches').insert(coach.toJson());
  }

  Future<void> updateCoach(String id, CoachModel coach) async {
    await SupabaseConfig.client
        .from('coaches')
        .update(coach.toJson())
        .eq('id', id);
  }

  Future<void> deleteCoach(String id) async {
    await SupabaseConfig.client.from('coaches').delete().eq('id', id);
  }

  Future<List<PlayerMediaItem>> getCoachMedia(String coachId) async {
    final res = await SupabaseConfig.client
        .from('media')
        .select()
        .eq('entity_type', 'coach')
        .eq('entity_id', coachId)
        .order('display_order')
        .order('created_at');
    return (res as List).map((json) => PlayerMediaItem.fromJson(json)).toList();
  }

  List<Map<String, dynamic>> _mediaPayload(List<PlayerMediaItem> items) {
    return items.map((item) {
      final json = item.toJson();
      if (item.id != null) json['id'] = item.id;
      return json;
    }).toList();
  }

  /// Cree un coach ET ses medias en une seule transaction.
  Future<CoachModel> createCoachWithMedia(
    CoachModel coach,
    List<PlayerMediaItem> mediaItems,
  ) async {
    final res = await SupabaseConfig.client.rpc(
      'admin_create_coach_with_media',
      params: {
        'p_coach': coach.toJson(),
        'p_media': _mediaPayload(mediaItems),
      },
    );
    return CoachModel.fromJson(res as Map<String, dynamic>);
  }

  /// Met a jour un coach ET diffe ses medias en une seule transaction.
  Future<CoachModel> updateCoachWithMedia(
    String coachId,
    CoachModel coach,
    List<PlayerMediaItem> mediaItems,
  ) async {
    final res = await SupabaseConfig.client.rpc(
      'admin_update_coach_with_media',
      params: {
        'p_coach_id': coachId,
        'p_coach': coach.toJson(),
        'p_media': _mediaPayload(mediaItems),
      },
    );
    return CoachModel.fromJson(res as Map<String, dynamic>);
  }

  /// Supprime un coach et ses medias en cascade.
  Future<void> deleteCoachWithMedia(String id) async {
    await SupabaseConfig.client
        .rpc('admin_delete_coach_cascade', params: {'p_coach_id': id});
  }
}
