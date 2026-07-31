import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/player_model.dart';
import '../../data/models/player_with_stats_model.dart';
import '../providers/public_players_provider.dart';

class PublicPlayerDetailScreen extends ConsumerWidget {
  final String playerId;

  const PublicPlayerDetailScreen({
    super.key,
    required this.playerId,
  });

  String _positionLabel(String? position) {
    switch ((position ?? '').toUpperCase()) {
      case 'ATT':
        return 'Attaquant';
      case 'DEF':
        return 'Défenseur';
      case 'MIL':
        return 'Milieu';
      case 'GK':
        return 'Gardien';
      default:
        return position ?? '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(publicPlayerDetailProvider(playerId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: detailsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (err, st) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(err),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (details) {
          final player = details.player;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppTheme.surfaceColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (player.coverImageUrl != null)
                        Image.network(
                          player.coverImageUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(Icons.sports_soccer,
                              size: 80, color: AppTheme.textSecondary),
                        ),
                      // Gradient overlay
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  AppTheme.accentGreen.withValues(alpha: 0.2),
                              backgroundImage: player.profileImageUrl != null
                                  ? NetworkImage(player.profileImageUrl!)
                                  : null,
                              child: player.profileImageUrl == null
                                  ? const Icon(Icons.person,
                                      size: 40, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (player.position != null)
                                        Text(
                                          _positionLabel(player.position),
                                          style: const TextStyle(
                                            color: AppTheme.accentGreen,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (player.position != null &&
                                          details.teamName != null)
                                        const Text(
                                          '  ·  ',
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 16),
                                        ),
                                      if (details.teamName != null)
                                        Flexible(
                                          child: Text(
                                            details.teamName!,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(player, details),
                      if (details.latestStats != null) ...[
                        const SizedBox(height: 20),
                        _buildStatsSection(details.latestStats!),
                      ],
                      const SizedBox(height: 24),
                      if (player.biography != null &&
                          player.biography!.isNotEmpty) ...[
                        const Text(
                          'Biographie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          player.biography!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(PlayerModel player, PlayerWithDetails details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          if (player.position != null) ...[
            _buildInfoRow(Icons.sports_outlined, 'Poste',
                _positionLabel(player.position)),
            const Divider(color: Colors.white12, height: 24),
          ],
          if (details.teamName != null) ...[
            _buildInfoRow(Icons.shield_outlined, 'Équipe', details.teamName!),
            const Divider(color: Colors.white12, height: 24),
          ],
          _buildInfoRow(Icons.numbers, 'Numéro',
              player.jerseyNumber?.toString() ?? 'N/A'),
          const Divider(color: Colors.white12, height: 24),
          if (details.age != null) ...[
            _buildInfoRow(Icons.cake_outlined, 'Âge', '${details.age} ans'),
            const Divider(color: Colors.white12, height: 24),
          ],
          _buildInfoRow(
              Icons.flag_outlined, 'Nationalité', player.nationality ?? 'N/A'),
          if (player.heightCm != null) ...[
            const Divider(color: Colors.white12, height: 24),
            _buildInfoRow(Icons.height, 'Taille', '${player.heightCm} cm'),
          ],
          if (player.weightKg != null) ...[
            const Divider(color: Colors.white12, height: 24),
            _buildInfoRow(Icons.fitness_center, 'Poids', '${player.weightKg} kg'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(PlayerStatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
                Icons.stadium_outlined, '${stats.matchesPlayed}', 'Matchs'),
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(
            child: _buildStatItem(
                Icons.sports_soccer, '${stats.goals}', 'Buts'),
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(
            child: _buildStatItem(
                Icons.assistant_outlined, '${stats.assists}', 'Passes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentGreen, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentGreen, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}