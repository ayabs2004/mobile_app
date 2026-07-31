import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/public_players_provider.dart';

class PublicAmateursListScreen extends ConsumerWidget {
  final String sportId;
  final String? sportName;

  const PublicAmateursListScreen({
    super.key,
    required this.sportId,
    this.sportName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amateursAsync = ref.watch(publicAmateurPlayersBySportProvider(sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(sportName != null ? 'Amateurs · $sportName' : 'Amateurs'),
      ),
      body: amateursAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        error: (e, st) => Center(
          child: Text(ErrorUtils.friendlyMessage(e),
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        data: (players) {
          if (players.isEmpty) {
            return const Center(
              child: Text('Aucun joueur amateur pour le moment.',
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
                            if (player.position != null || player.teamName != null)
                              Text(
                                [
                                  if (player.position != null) player.position!,
                                  if (player.teamName != null) player.teamName!,
                                ].join(' · '),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 12),
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