import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../providers/fantasy_provider.dart';

class FantasyTeamBuilderScreen extends ConsumerStatefulWidget {
  final String? sportId;
  final String? sportName;

  const FantasyTeamBuilderScreen({super.key, this.sportId, this.sportName});

  @override
  ConsumerState<FantasyTeamBuilderScreen> createState() =>
      _FantasyTeamBuilderScreenState();
}

class _FantasyTeamBuilderScreenState
    extends ConsumerState<FantasyTeamBuilderScreen> {
  bool _initialized = false;
  bool _saving = false;

  double _totalCost(List<FantasyPricedPlayer> allPlayers, Set<String> selectedIds) {
    return allPlayers
        .where((p) => selectedIds.contains(p.player.id))
        .fold(0.0, (sum, p) => sum + p.cost);
  }

  Future<void> _save(String roundId) async {
    final selectedIds = ref.read(fantasyTeamBuilderProvider);
    final captainId = ref.read(fantasyCaptainProvider);

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne au moins un joueur.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(fantasyRepositoryProvider).saveTeam(
            roundId: roundId,
            playerIds: selectedIds.toList(),
            captainPlayerId: captainId,
          );
      if (!mounted) return;
      ref.invalidate(myFantasyTeamProvider(roundId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Équipe enregistrée !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.friendlyMessage(e, context: "l'enregistrement de l'équipe"))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportId = widget.sportId;

    if (sportId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Compose ton équipe')),
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

    final roundAsync = ref.watch(currentFantasyRoundProvider(sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.sportName != null
              ? 'Compose ton équipe · ${widget.sportName}'
              : 'Compose ton équipe',
        ),
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
                'Aucun round fantasy ouvert pour le moment.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final playersAsync =
              ref.watch(fantasyPricedPlayersProvider(widget.sportId));
          final myTeamAsync = ref.watch(myFantasyTeamProvider(round.id));

          return playersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                ErrorUtils.friendlyMessage(e, context: 'le chargement des joueurs'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (allPlayers) {
              // Pré-remplit la sélection avec l'équipe existante (une seule fois).
              myTeamAsync.whenData((team) {
                if (!_initialized && team != null) {
                  _initialized = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(fantasyTeamBuilderProvider.notifier)
                        .reset(team.playerIds);
                    ref.read(fantasyCaptainProvider.notifier).state =
                        team.captainPlayerId;
                  });
                }
              });

              final selectedIds = ref.watch(fantasyTeamBuilderProvider);
              final captainId = ref.watch(fantasyCaptainProvider);
              final spent = _totalCost(allPlayers, selectedIds);
              final remaining = round.budget - spent;
              final overBudget = remaining < 0;
              final overCount = selectedIds.length > round.maxPlayers;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.surfaceColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedIds.length} / ${round.maxPlayers} joueurs',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Budget restant : ${remaining.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: overBudget ? Colors.redAccent : AppTheme.accentGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: allPlayers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Aucun joueur fantasy disponible pour ce sport.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: allPlayers.length,
                      itemBuilder: (context, index) {
                        final priced = allPlayers[index];
                        final isSelected = selectedIds.contains(priced.player.id);
                        final isCaptain = captainId == priced.player.id;

                        return Card(
                          color: AppTheme.surfaceColor,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              activeColor: AppTheme.accentGreen,
                              onChanged: (_) => ref
                                  .read(fantasyTeamBuilderProvider.notifier)
                                  .toggle(priced.player.id),
                            ),
                            title: Text(
                              priced.player.fullName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${priced.player.position ?? ''} · ${priced.player.teamName ?? ''}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  priced.cost.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isSelected)
                                  IconButton(
                                    icon: Icon(
                                      isCaptain ? Icons.star : Icons.star_border,
                                      color: isCaptain ? Colors.amber : Colors.white38,
                                    ),
                                    tooltip: 'Désigner capitaine',
                                    onPressed: () {
                                      ref.read(fantasyCaptainProvider.notifier).state =
                                          priced.player.id;
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_saving || overBudget || overCount || !round.isOpen)
                            ? null
                            : () => _save(round.id),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enregistrer mon équipe'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}