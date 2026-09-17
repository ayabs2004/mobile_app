import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../sports/presentation/providers/sports_provider.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../core/fantasy_sport_utils.dart';
import '../../data/models/fantasy_round_model.dart';
import '../providers/admin_fantasy_provider.dart';

/// Gestion des rounds fantasy : créer/nommer un round pour un sport (foot
/// ou hand), et l'ouvrir/fermer.
///
/// Il n'y a plus d'attribution manuelle des points ici : chaque joueur a
/// déjà ses stats (matchs, buts, cartons, minutes...) saisies dans son
/// formulaire, qui calculent automatiquement son score. Ouvrir un round
/// pour un sport suffit : tous les joueurs (pro + amateur, hors académie)
/// de ce sport sont alors proposés par défaut aux utilisateurs.
class AdminFantasyRoundsScreen extends ConsumerStatefulWidget {
  const AdminFantasyRoundsScreen({super.key});

  @override
  ConsumerState<AdminFantasyRoundsScreen> createState() =>
      _AdminFantasyRoundsScreenState();
}

class _AdminFantasyRoundsScreenState
    extends ConsumerState<AdminFantasyRoundsScreen> {
  Future<void> _showCreateRoundDialog(List<SportModel> fantasySports) async {
    final nameController = TextEditingController();
    String? selectedSportId =
        fantasySports.isNotEmpty ? fantasySports.first.id : null;
    bool creating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Nouveau round',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedSportId,
                dropdownColor: AppTheme.surfaceColor,
                decoration: const InputDecoration(labelText: 'Sport'),
                items: fantasySports
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.iconEmoji ?? ''} ${s.name}'.trim(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedSportId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nom du round'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final sportId = selectedSportId;
                      if (name.isEmpty || sportId == null) return;

                      setDialogState(() => creating = true);
                      try {
                        await ref
                            .read(adminFantasyRepositoryProvider)
                            .createRound(name: name, sportId: sportId);

                        // On ferme d'abord la dialog, AVANT de toucher au
                        // provider/état de la page en dessous, pour éviter
                        // de reconstruire l'arbre pendant que la route de la
                        // dialog est encore en train de se fermer.
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!mounted) return;
                        ref.invalidate(adminFantasyRoundsProvider);
                      } catch (e) {
                        setDialogState(() => creating = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              ErrorUtils.friendlyMessage(
                                  e, context: 'la création du round'),
                            ),
                          ),
                        );
                      }
                    },
              child: creating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _toggleRoundStatus(FantasyRoundModel round) async {
    final newStatus = round.status == 'open' ? 'closed' : 'open';
    try {
      await ref
          .read(adminFantasyRepositoryProvider)
          .setRoundStatus(round.id, newStatus);
      ref.invalidate(adminFantasyRoundsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorUtils.friendlyMessage(e, context: 'le changement de statut'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roundsAsync = ref.watch(adminFantasyRoundsProvider);
    final sportsAsync = ref.watch(sportsListProvider);

    final fantasySports =
        sportsAsync.valueOrNull?.where(isFantasySport).toList() ?? [];
    final sportsById = {for (final s in fantasySports) s.id: s};

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rounds fantasy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau round',
            onPressed: fantasySports.isEmpty
                ? null
                : () => _showCreateRoundDialog(fantasySports),
          ),
        ],
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement des rounds'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun round créé pour le moment. Ouvre-en un pour '
                  "le foot ou le hand : tous les joueurs (hors académie) "
                  "de ce sport seront proposés aux utilisateurs.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rounds.length,
            itemBuilder: (context, index) {
              final round = rounds[index];
              final sport = sportsById[round.sportId];

              return Card(
                color: AppTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              round.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sport != null
                                  ? '${sport.iconEmoji ?? ''} ${sport.name}'
                                      .trim()
                                  : 'Sport inconnu',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: round.status == 'open',
                            onChanged: (_) => _toggleRoundStatus(round),
                          ),
                          Text(
                            round.status == 'open' ? 'Ouvert' : 'Fermé',
                            style: TextStyle(
                              color: round.status == 'open'
                                  ? AppTheme.accentGreen
                                  : Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
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
