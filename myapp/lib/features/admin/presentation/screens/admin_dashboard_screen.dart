import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/admin_stats_provider.dart';
import '../providers/current_profile_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            color: AppTheme.surfaceColor,
            onSelected: (route) => context.push(route),
           itemBuilder: (context) => [
  const PopupMenuItem(value: '/admin/sports', child: Text('Sports & compétitions', style: TextStyle(color: Colors.white))),
  const PopupMenuItem(value: '/admin/players', child: Text('Joueurs', style: TextStyle(color: Colors.white))),
  const PopupMenuItem(value: '/admin/amateurs', child: Text('Amateurs', style: TextStyle(color: Colors.white))),
  const PopupMenuItem(value: '/admin/coaches', child: Text('Coachs', style: TextStyle(color: Colors.white))),
  const PopupMenuItem(value: '/admin/users', child: Text('Utilisateurs', style: TextStyle(color: Colors.white))),
  if (isSuperAdmin) ...[
    const PopupMenuDivider(),
    const PopupMenuItem(value: '/admin/sub-admins', child: Text('Sous-admins', style: TextStyle(color: Colors.white))),
    const PopupMenuItem(value: '/admin/audit-log', child: Text('Historique des actions', style: TextStyle(color: Colors.white))),
  ],
],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentGreen,
        onRefresh: () async => ref.invalidate(adminDashboardStatsProvider),
        child: statsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGreen),
          ),
          error: (err, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                ErrorUtils.friendlyMessage(err),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.3,
                children: [
                  _StatCard(
                    label: 'Utilisateurs',
                    value: '${stats['total_users']}',
                    icon: Icons.people_outline,
                  ),
                  _StatCard(
                    label: 'Joueurs',
                    value: '${stats['total_players']}',
                    icon: Icons.sports_soccer,
                  ),
                  _StatCard(
                    label: 'Sports',
                    value: '${stats['total_competitions']}',
                    icon: Icons.emoji_events_outlined,
                  ),
                  _StatCard(
                    label: 'Visites (7j)',
                    value: '${stats['unique_visitors_week']}',
                    icon: Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _StatCard(
                label: 'Visiteurs uniques aujourd\'hui',
                value: '${stats['unique_visitors_today']}',
                icon: Icons.today_outlined,
                fullWidth: true,
              ),
              const SizedBox(height: 8),
              _StatCard(
                label: 'Ouvertures d\'app aujourd\'hui',
                value: '${stats['visits_today']}',
                icon: Icons.open_in_new,
                fullWidth: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Joueurs les plus consultés',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...(stats['top_players'] as List).map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['full_name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${p['views']} vues',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Icon(icon, color: AppTheme.accentGreen, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.accentGreen, size: 22),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
    );
  }
}