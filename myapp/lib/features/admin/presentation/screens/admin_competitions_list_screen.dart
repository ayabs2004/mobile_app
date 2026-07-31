import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../../sports/data/models/competition_model.dart';
import '../providers/admin_content_providers.dart';

/// Compétitions d'UN sport. L'écran s'arrête ici : plus de navigation
/// vers une liste de joueurs (la gestion des joueurs se fait désormais
/// depuis un écran séparé "Joueurs", accessible depuis la sidebar,
/// avec un filtre par sport).
class AdminCompetitionsListScreen extends ConsumerWidget {
  final SportModel sport;
  const AdminCompetitionsListScreen({super.key, required this.sport});

  Future<void> _confirmAndDelete(
      BuildContext context, WidgetRef ref, CompetitionModel competition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Supprimer cette compétition ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '"${competition.name}" ainsi que tous ses joueurs seront '
          'définitivement supprimés. Cette action est irréversible.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(adminSportsRepositoryProvider)
          .deleteCompetition(competition.id);
      ref.invalidate(adminCompetitionsBySportProvider(sport.id));
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Compétition supprimée');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
      }
    }
  }

  Future<void> _showCompetitionDialog(
    BuildContext context,
    WidgetRef ref, {
    CompetitionModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            existing == null ? 'Nouvelle compétition' : 'Modifier la compétition',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Nom (ex: Ligue 1, Coupe de Tunisie)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final repo = ref.read(adminSportsRepositoryProvider);
                if (existing == null) {
                  final slug = nameController.text
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
                      .replaceAll(RegExp(r'\s+'), '-');
                  await repo.createCompetition({
                    'sport_id': sport.id,
                    'name': nameController.text.trim(),
                    'slug': slug,
                  });
                } else {
                  await repo.updateCompetition(existing.id, {
                    'name': nameController.text.trim(),
                  });
                }
                ref.invalidate(adminCompetitionsBySportProvider(sport.id));
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionsAsync =
        ref.watch(adminCompetitionsBySportProvider(sport.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${sport.iconEmoji ?? ""} ${sport.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouvelle compétition',
            onPressed: () => _showCompetitionDialog(context, ref),
          ),
        ],
      ),
      body: competitionsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        error: (e, st) => Center(
            child: Text(ErrorUtils.friendlyMessage(e),
                style: const TextStyle(color: AppTheme.textSecondary))),
        data: (competitions) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: competitions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final competition = competitions[index];
            return Material(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showCompetitionDialog(context, ref,
                    existing: competition),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(competition.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary),
                        onPressed: () => _showCompetitionDialog(context, ref,
                            existing: competition),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () =>
                            _confirmAndDelete(context, ref, competition),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}