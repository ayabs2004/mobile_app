import '../../../../core/config/supabase_config.dart';
import '../../../coaches/data/models/coach_model.dart';

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
}