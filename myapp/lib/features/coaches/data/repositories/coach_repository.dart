import '../../../../core/config/supabase_config.dart';
import '../models/coach_model.dart';

/// Lecture publique des coachs (contrairement à AdminCoachesRepository qui
/// gère le CRUD admin). Ne renvoie que les coachs actifs.
class PublicCoachesRepository {
  Future<List<CoachModel>> getAllCoaches() async {
    final res = await SupabaseConfig.client
        .from('coaches')
        .select()
        .eq('is_active', true)
        .order('full_name');
    return (res as List).map((j) => CoachModel.fromJson(j)).toList();
  }

  Future<List<CoachModel>> getCoachesBySport(String sportId) async {
    final res = await SupabaseConfig.client
        .from('coaches')
        .select()
        .eq('sport_id', sportId)
        .eq('is_active', true)
        .order('full_name');
    return (res as List).map((j) => CoachModel.fromJson(j)).toList();
  }

  Future<CoachModel> getCoachById(String id) async {
    final res =
        await SupabaseConfig.client.from('coaches').select().eq('id', id).single();
    return CoachModel.fromJson(res);
  }
}