import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../providers/fantasy_provider.dart';
import 'package:go_router/go_router.dart';
class FantasyMyTeamScreen extends ConsumerWidget {
  final String? sportId;
  final String? sportName;

  const FantasyMyTeamScreen({super.key, this.sportId, this.sportName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = sportId;
    if (sport == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Mon équipe')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ouvre le fantasy depuis la page d\'un sport (foot ou hand).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final roundAsync = ref.watch(currentFantasyRoundProvider(sport));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(sportName != null ? 'Mon équipe · $sportName' : 'Mon équipe'),
      ),
      body: roundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement du round'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (round) {
          if (round == null) {
            return const Center(
              child: Text(
                'Aucun round fantasy actif pour le moment.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final teamAsync = ref.watch(myFantasyTeamProvider(round.id));
          // null : l'équipe déjà enregistrée est forcément déjà cohérente
          // avec un seul sport, pas besoin de refiltrer ici.
          final playersAsync = ref.watch(fantasyPricedPlayersProvider(null));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myFantasyTeamProvider(round.id));
              await ref.read(myFantasyTeamProvider(round.id).future);
            },
            child: teamAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  ErrorUtils.friendlyMessage(e, context: "le chargement de l'équipe"),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              data: (team) {
                if (team == null || team.playerIds.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      const Center(
                        child: Text(
                          "Tu n'as pas encore composé d'équipe pour ce round.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => context.go('/fantasy', extra: {'sportId': sport, 'sportName': sportName}),
                          child: const Text('Composer mon équipe'),
                        ),
                      ),
                    ],
                  );
                }

                return playersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      ErrorUtils.friendlyMessage(e, context: 'le chargement des joueurs'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  data: (allPlayers) {
                    final byId = <String, FantasyPricedPlayer>{
                      for (final p in allPlayers) p.player.id: p,
                    };

                    final myPlayers = team.playerIds
                        .where((id) => byId.containsKey(id))
                        .map((id) => byId[id]!)
                        .toList();

                    final totalCost =
                        myPlayers.fold<double>(0.0, (sum, p) => sum + p.cost);

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${myPlayers.length} / ${round.maxPlayers} joueurs',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Coût : ${totalCost.toStringAsFixed(1)} / ${round.budget.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...myPlayers.map((p) {
                          final isCaptain = team.captainPlayerId == p.player.id;
                          return Card(
                            color: AppTheme.surfaceColor,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: isCaptain
                                  ? const Icon(Icons.star, color: Colors.amber)
                                  : const Icon(Icons.person_outline,
                                      color: Colors.white38),
                              title: Text(
                                p.player.fullName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${p.player.position ?? ''} · ${p.player.teamName ?? ''}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: Text(
                                p.cost.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.go('/fantasy', extra: {'sportId': sport, 'sportName': sportName}),
                            child: const Text('Modifier mon équipe'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}