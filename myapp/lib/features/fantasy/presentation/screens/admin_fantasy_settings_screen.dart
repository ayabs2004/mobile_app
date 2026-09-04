import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../../sports/presentation/providers/sports_provider.dart';
import '../../core/fantasy_sport_utils.dart';
import '../../data/models/fantasy_sport_settings_model.dart';
import '../providers/admin_fantasy_provider.dart';

/// Réglages fantasy par sport (budget, effectif max, max par club).
/// Remplace l'ancien écran de gestion des rounds : le fantasy tourne
/// désormais en continu, il n'y a plus de période à ouvrir/fermer, juste
/// des réglages globaux par sport (foot ou hand).
class AdminFantasySettingsScreen extends ConsumerWidget {
  const AdminFantasySettingsScreen({super.key});

  Future<void> _editSettings(
    BuildContext context,
    WidgetRef ref,
    SportModel sport,
    FantasySportSettingsModel current,
  ) async {
    final budgetController =
        TextEditingController(text: current.budget.toStringAsFixed(1));
    final maxPlayersController =
        TextEditingController(text: current.maxPlayers.toString());
    final maxPerClubController =
        TextEditingController(text: current.maxPerClub.toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Réglages · ${sport.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxPlayersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Effectif max'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxPerClubController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max par club'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final budget = double.tryParse(budgetController.text.replaceAll(',', '.'));
    final maxPlayers = int.tryParse(maxPlayersController.text);
    final maxPerClub = int.tryParse(maxPerClubController.text);

    if (budget == null || maxPlayers == null || maxPerClub == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valeurs invalides.')),
      );
      return;
    }

    try {
      await ref.read(adminFantasyRepositoryProvider).upsertSportSettings(
            sportId: sport.id,
            budget: budget,
            maxPlayers: maxPlayers,
            maxPerClub: maxPerClub,
          );
      ref.invalidate(adminFantasySportSettingsProvider(sport.id));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorUtils.friendlyMessage(e, context: "l'enregistrement des réglages"),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(sportsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Réglages fantasy')),
      body: sportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement des sports'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (sports) {
          final fantasySports = sports.where(isFantasySport).toList();

          if (fantasySports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun sport éligible au fantasy pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: fantasySports.length,
            itemBuilder: (context, index) {
              final sport = fantasySports[index];
              final settingsAsync =
                  ref.watch(adminFantasySportSettingsProvider(sport.id));

              return Card(
                color: AppTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: settingsAsync.when(
                  loading: () => const ListTile(
                    title: Text('Chargement…', style: TextStyle(color: Colors.white70)),
                  ),
                  error: (e, _) => ListTile(
                    title: Text(sport.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      ErrorUtils.friendlyMessage(e, context: 'le chargement des réglages'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  data: (settings) => ListTile(
                    title: Text(sport.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Budget ${settings.budget.toStringAsFixed(1)} · '
                      '${settings.maxPlayers} joueurs max · '
                      '${settings.maxPerClub} par club max',
                      style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                    ),
                    trailing: const Icon(Icons.edit_outlined, color: Colors.white70),
                    onTap: () => _editSettings(context, ref, sport, settings),
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
