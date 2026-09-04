import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/public_players_provider.dart';

class PublicAcademiesListScreen extends ConsumerWidget {
  final String sportId;
  final String? sportName;

  const PublicAcademiesListScreen({
    super.key,
    required this.sportId,
    this.sportName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academiesAsync = ref.watch(publicAcademiePlayersBySportProvider(sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(sportName != null ? 'Académies · $sportName' : 'Académies'),
      ),
      body: academiesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        error: (e, st) => Center(
          child: Text(ErrorUtils.friendlyMessage(e),
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (players) {
          if (players.isEmpty) {
            return const Center(
              child: Text('Aucun joueur académie pour le moment.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final player = players[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: () => context.push('/player/${player.id}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.2),
                        backgroundImage: player.profileImageUrl != null
                            ? NetworkImage(player.profileImageUrl!)
                            : null,
                        child: player.profileImageUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player.fullName,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
                            if (player.niveau != null || player.position != null)
                              Row(
                                children: [
                                  if (player.niveau != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        player.niveau!,
                                        style: const TextStyle(
                                          color: AppTheme.accentGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  if (player.niveau != null && player.position != null)
                                    const SizedBox(width: 6),
                                  if (player.position != null)
                                    Flexible(
                                      child: Text(
                                        player.position!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: AppTheme.textSecondary),
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
