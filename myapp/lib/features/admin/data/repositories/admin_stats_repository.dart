import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';
// AnalyticsRepository vit maintenant dans core/ (partagée par tous les
// modules) ; on la ré-exporte ici pour ne pas casser les imports existants.
export '../../../../core/analytics/analytics_repository.dart';

class AdminStatsRepository {
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response =
        await SupabaseConfig.client.rpc('get_admin_dashboard_stats');

    return Map<String, dynamic>.from(response as Map<String, dynamic>);
  }
}