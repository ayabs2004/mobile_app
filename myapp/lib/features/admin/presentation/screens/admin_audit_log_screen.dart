import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/audit_log_entry.dart';
import '../../data/repositories/admin_users_repository.dart';
import '../providers/admin_content_providers.dart';

class AdminAuditLogScreen extends ConsumerStatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  ConsumerState<AdminAuditLogScreen> createState() =>
      _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends ConsumerState<AdminAuditLogScreen> {
  String? _selectedActorId;

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(
      adminAuditLogProvider(
        AuditLogFilter(actorId: _selectedActorId),
      ),
    );
    final subAdminsAsync = ref.watch(adminSubAdminsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Historique des actions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: subAdminsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (subAdmins) => _ActorFilter(
                subAdmins: subAdmins,
                selectedActorId: _selectedActorId,
                onChanged: (id) => setState(() => _selectedActorId = id),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: auditAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accentGreen),
              ),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    ErrorUtils.friendlyMessage(e),
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune action enregistrée.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.accentGreen,
                  onRefresh: () async => ref.invalidate(
                    adminAuditLogProvider(
                      AuditLogFilter(actorId: _selectedActorId),
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _AuditLogTile(entry: entries[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorFilter extends StatelessWidget {
  final List<UserProfileModel> subAdmins;
  final String? selectedActorId;
  final ValueChanged<String?> onChanged;

  const _ActorFilter({
    required this.subAdmins,
    required this.selectedActorId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: selectedActorId,
          dropdownColor: AppTheme.surfaceColor,
          hint: const Text('Tous les sous-admins',
              style: TextStyle(color: AppTheme.textSecondary)),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tous les sous-admins',
                  style: TextStyle(color: Colors.white)),
            ),
            ...subAdmins.map(
              (u) => DropdownMenuItem<String?>(
                value: u.id,
                child: Text(u.fullName ?? 'Sans nom',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLogEntry entry;

  const _AuditLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final actorName = entry.actorName ?? 'Admin inconnu';
    final label = entry.entityLabel ?? 'élément';

    IconData icon;
    Color iconColor;
    switch (entry.action) {
      case 'create':
        icon = Icons.add_circle_outline;
        iconColor = AppTheme.accentGreen;
        break;
      case 'update':
        icon = Icons.edit_outlined;
        iconColor = Colors.orange;
        break;
      case 'delete':
        icon = Icons.delete_outline;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: actorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${entry.actionLabel} '),
                      TextSpan(
                        text: entry.entityTypeLabel,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$label"',
                  style: const TextStyle(
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateFormat.format(entry.createdAt.toLocal()),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (entry.detailLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: entry.detailLines.map((line) {
                        if (line.isNew) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${line.label} : ${line.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                                children: [
                                  TextSpan(
                                      text: '${line.label} : ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  TextSpan(
                                    text: line.oldValue ?? '',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const TextSpan(text: ' ➔ '),
                                  TextSpan(
                                    text: line.value,
                                    style: const TextStyle(
                                        color: AppTheme.accentGreen),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
