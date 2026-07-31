import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_stats_repository.dart';

final adminStatsRepositoryProvider = Provider((ref) => AdminStatsRepository());
final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

final adminDashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(adminStatsRepositoryProvider).getDashboardStats();
});