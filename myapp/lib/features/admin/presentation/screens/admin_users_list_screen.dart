import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../core/admin_role_utils.dart';
import '../providers/admin_content_providers.dart';
import '../providers/current_profile_provider.dart';

class AdminUsersListScreen extends ConsumerStatefulWidget {
  const AdminUsersListScreen({super.key});

  @override
  ConsumerState<AdminUsersListScreen> createState() =>
      _AdminUsersListScreenState();
}

/// Filtre de rôle : `null` = tous les rôles.
class _RoleFilter {
  final String? role;
  final String label;
  const _RoleFilter(this.role, this.label);
}

const _roleFilters = [
  _RoleFilter(null, 'Tous'),
  _RoleFilter('customer', 'Utilisateurs'),
  _RoleFilter('admin', 'Admins'),
  _RoleFilter('super_admin', 'Super admins'),
];

class _AdminUsersListScreenState extends ConsumerState<AdminUsersListScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersListProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Utilisateurs & Rôles')),
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.black,
              onPressed: () => context.push('/admin/sub-admins'),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Gérer les sous-admins'),
            )
          : null,
      body: Column(
        children: [
          // ---------- FILTRES DE RÔLE ----------
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _roleFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _roleFilters[index];
                final selected = filter.role == _selectedRole;
                return InkWell(
                  onTap: () => setState(() => _selectedRole = filter.role),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accentGreen
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accentGreen)),
              error: (e, st) => Center(
                  child: Text(ErrorUtils.friendlyMessage(e),
                      style: const TextStyle(color: AppTheme.textSecondary))),
              data: (allUsers) {
                final users = _selectedRole == null
                    ? allUsers
                    : allUsers.where((u) => u.role == _selectedRole).toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text('Aucun utilisateur pour ce filtre.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final badgeColor = switch (user.role) {
                      'super_admin' => Colors.amber,
                      'admin' => AppTheme.accentGreen,
                      _ => AppTheme.textSecondary,
                    };
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(user.fullName ?? 'Sans nom',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(roleDisplayLabel(user.role),
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}