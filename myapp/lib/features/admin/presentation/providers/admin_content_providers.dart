import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_sports_repository.dart';
import '../../data/repositories/admin_coaches_repository.dart';

import '../../data/repositories/admin_users_repository.dart';
import '../../data/repositories/admin_audit_repository.dart';
import '../../data/models/audit_log_entry.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../../sports/data/models/competition_model.dart';
import '../../../coaches/data/models/coach_model.dart';


// ---- Sports & Competitions ----
final adminSportsRepositoryProvider = Provider((ref) => AdminSportsRepository());
final adminSportsListProvider = FutureProvider<List<SportModel>>(
    (ref) => ref.read(adminSportsRepositoryProvider).getAllSports());

final adminCompetitionsBySportProvider =
    FutureProvider.family<List<CompetitionModel>, String>((ref, sportId) {
  return ref
      .read(adminSportsRepositoryProvider)
      .getCompetitionsForSport(sportId);
});

// ---- Coaches ----
final adminCoachesRepositoryProvider = Provider((ref) => AdminCoachesRepository());
final adminCoachesListProvider =
    FutureProvider.family<List<CoachModel>, String?>((ref, sportId) {
  final repo = ref.read(adminCoachesRepositoryProvider);
  return sportId == null ? repo.getAllCoaches() : repo.getCoachesBySport(sportId);
});
// ---- Academies ----
// NB : plus de getJoinRequests()/adminJoinRequestsListProvider ici -- la
// table academy_join_requests et l'écran associé sont supprimés (v5).

// ---- Users ----
final adminUsersRepositoryProvider = Provider((ref) => AdminUsersRepository());
final adminUsersListProvider = FutureProvider<List<UserProfileModel>>(
    (ref) => ref.read(adminUsersRepositoryProvider).getAllUsers());
final adminSubAdminsListProvider = FutureProvider<List<UserProfileModel>>(
    (ref) => ref.read(adminUsersRepositoryProvider).getSubAdmins());

// ---- Audit log (super admin only) ----
final adminAuditRepositoryProvider =
    Provider((ref) => AdminAuditRepository());

class AuditLogFilter {
  final String? actorId;
  const AuditLogFilter({this.actorId});

  @override
  bool operator ==(Object other) =>
      other is AuditLogFilter && other.actorId == actorId;

  @override
  int get hashCode => actorId.hashCode;
}

final adminAuditLogProvider =
    FutureProvider.family<List<AuditLogEntry>, AuditLogFilter>((ref, filter) {
  return ref.read(adminAuditRepositoryProvider).getAuditLog(
        actorId: filter.actorId,
      );
});