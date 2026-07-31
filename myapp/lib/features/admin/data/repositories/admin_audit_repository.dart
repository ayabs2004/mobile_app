import '../../../../core/config/supabase_config.dart';
import '../models/audit_log_entry.dart';

class AdminAuditRepository {
  Future<List<AuditLogEntry>> getAuditLog({
    String? actorId,
    String? entityType,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = SupabaseConfig.client
        .from('admin_audit_log')
        .select('*, actor:profiles!actor_id(full_name)');

    if (actorId != null) {
      query = query.eq('actor_id', actorId);
    }
    if (entityType != null) {
      query = query.eq('entity_type', entityType);
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List)
        .map((j) => AuditLogEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
