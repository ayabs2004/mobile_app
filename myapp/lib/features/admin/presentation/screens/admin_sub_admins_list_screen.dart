import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/admin_content_providers.dart';

class AdminSubAdminsListScreen extends ConsumerWidget {
  const AdminSubAdminsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAdminsAsync = ref.watch(adminSubAdminsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Sous-admins')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/admin/sub-admins/create'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Créer un sous-admin'),
      ),
      body: subAdminsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (e, st) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (subAdmins) {
          if (subAdmins.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aucun sous-admin pour le moment.\n'
                  'Créez-en un via le bouton ci-dessous.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: subAdmins.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = subAdmins[index];
              return InkWell(
                onTap: () => context.push(
                  '/admin/sub-admins/edit/${user.id}',
                  extra: user,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppTheme.accentGreen.withValues(alpha: 0.15),
                        child: const Icon(Icons.shield_outlined,
                            color: AppTheme.accentGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? 'Sans nom',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Sous-admin',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
