import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/coachs_provider.dart';
import '../../data/models/coach_model.dart';

class PublicCoachDetailScreen extends ConsumerWidget {
  final String coachId;

  const PublicCoachDetailScreen({super.key, required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(publicCoachDetailProvider(coachId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: coachAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (err, st) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(err),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (coach) {
          final currentTeam = coach.currentTeam;
          final pastTeams = coach.pastTeams;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.surfaceColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coach.photoUrl != null)
                        Image.network(coach.photoUrl!, fit: BoxFit.cover)
                      else
                        Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(Icons.sports,
                              size: 80, color: AppTheme.textSecondary),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppTheme.backgroundColor.withValues(alpha: 0.8),
                              AppTheme.backgroundColor,
                            ],
                            stops: const [0.5, 0.8, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coach.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (currentTeam != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Actuellement à ${currentTeam.teamName}',
                                style: const TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (coach.yearsExperience != null)
                      _InfoRow(
                        icon: Icons.timeline,
                        label: 'Expérience',
                        value: '${coach.yearsExperience} ans',
                      ),
                    if (currentTeam != null)
                      _InfoRow(
                        icon: Icons.shield_outlined,
                        label: 'Équipe actuelle',
                        value:
                            '${currentTeam.teamName} (depuis ${currentTeam.startYear})',
                      ),
                    if (coach.contactEmail != null)
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Contact',
                        value: coach.contactEmail!,
                      ),
                    if (coach.certifications.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'CERTIFICATIONS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: coach.certifications.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c,
                              style: const TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    // Prob4 fix: afficher TOUTES les expériences (actuelles + passées)
                    if (coach.teamHistory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'EXPÉRIENCES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...coach.teamHistory.map((team) => _TeamHistoryTile(team: team)),
                    ],
                    if (coach.biography != null &&
                        coach.biography!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'BIOGRAPHIE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        coach.biography!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentGreen, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamHistoryTile extends StatelessWidget {
  final CoachTeamExperience team;

  const _TeamHistoryTile({required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: team.isCurrent
                  ? AppTheme.accentGreen.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: team.isCurrent ? AppTheme.accentGreen : Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        team.teamName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  team.isCurrent
                      ? 'Depuis ${team.startYear} · ${team.durationYears} an(s)'
                      : '${team.startYear} – ${team.endYear} · ${team.durationYears} an(s)',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}