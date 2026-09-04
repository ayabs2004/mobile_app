import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../providers/fantasy_provider.dart';
import '../widgets/fantasy_formation_pitch.dart';
import '../widgets/fantasy_player_pick_card.dart';

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

    final settingsAsync = ref.watch(fantasySportSettingsProvider(sport));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(sportName != null ? 'Mon équipe · $sportName' : 'Mon équipe'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement des réglages'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (settings) {
          final teamAsync = ref.watch(myFantasyTeamProvider(sport));
          // null : l'équipe déjà enregistrée est forcément déjà cohérente
          // avec un seul sport, pas besoin de refiltrer ici.
          final playersAsync = ref.watch(fantasyPricedPlayersProvider(null));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myFantasyTeamProvider(sport));
              await ref.read(myFantasyTeamProvider(sport).future);
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
                      const SizedBox(height: 100),
                      Icon(Icons.stadium_outlined,
                          size: 56, color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(height: 16),
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "Tu n'as pas encore composé d'équipe.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

                    final captain = team.captainPlayerId == null
                        ? null
                        : byId[team.captainPlayerId];

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // --- Terrain / stade avec la composition ---
                        FantasyFormationPitch(
                          selectedPlayers: myPlayers,
                          captainId: team.captainPlayerId,
                          height: 400,
                        ),
                        const SizedBox(height: 14),

                        // --- Résumé équipe ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SummaryStat(
                                icon: Icons.groups_rounded,
                                label: '${myPlayers.length} / ${settings.maxPlayers}',
                                caption: 'joueurs',
                              ),
                              Container(width: 1, height: 32, color: Colors.white12),
                              _SummaryStat(
                                icon: Icons.savings_rounded,
                                label:
                                    '${totalCost.toStringAsFixed(1)} / ${settings.budget.toStringAsFixed(1)}',
                                caption: 'budget utilisé',
                              ),
                              if (captain != null) ...[
                                Container(width: 1, height: 32, color: Colors.white12),
                                _SummaryStat(
                                  icon: Icons.star,
                                  iconColor: Colors.amber,
                                  label: captain.player.fullName.split(' ').last,
                                  caption: 'capitaine',
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Effectif',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        ...myPlayers.map((p) {
                          final isCaptain = team.captainPlayerId == p.player.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ReadOnlyPlayerCard(
                              priced: p,
                              isCaptain: isCaptain,
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => context.go('/fantasy', extra: {'sportId': sport, 'sportName': sportName}),
                            label: const Text('Modifier mon équipe'),
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

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String caption;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.caption,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor ?? AppTheme.accentGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          caption,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _ReadOnlyPlayerCard extends StatelessWidget {
  final FantasyPricedPlayer priced;
  final bool isCaptain;

  const _ReadOnlyPlayerCard({required this.priced, required this.isCaptain});

  @override
  Widget build(BuildContext context) {
    final player = priced.player;
    final color = positionColor(player.position);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCaptain
              ? Colors.amber.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.18),
                backgroundImage: player.profileImageUrl != null
                    ? CachedNetworkImageProvider(player.profileImageUrl!)
                    : null,
                child: player.profileImageUrl == null
                    ? Icon(Icons.person, color: color, size: 22)
                    : null,
              ),
              Positioned(
                bottom: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    positionShortLabel(player.position),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (isCaptain)
                const Positioned(
                  top: -6,
                  right: -6,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.star, color: Colors.black, size: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  player.teamName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(
            priced.cost.toStringAsFixed(1),
            style: const TextStyle(
              color: AppTheme.accentGreen,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
