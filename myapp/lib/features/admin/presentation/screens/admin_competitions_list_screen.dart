import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../sports/data/models/sport_model.dart';
import '../../../sports/data/models/competition_model.dart';
import '../../../sports/presentation/providers/sports_provider.dart';
import '../providers/admin_content_providers.dart';
import 'package:go_router/go_router.dart';
/// Compétitions et Sections d'UN sport.
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
    final sportsAsync = ref.watch(adminSportsListProvider);
    final currentSport = sportsAsync.valueOrNull?.firstWhere((s) => s.id == sport.id) ?? sport;

    final competitionsAsync = ref.watch(adminCompetitionsBySportProvider(sport.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${currentSport.iconEmoji ?? ""} ${currentSport.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouvelle section',
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
        data: (competitions) {
          final orderedCompetitions = [...competitions]..sort((a,b) => a.displayOrder.compareTo(b.displayOrder));
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: orderedCompetitions.length + 1,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex >= orderedCompetitions.length) return; // Don't move Amateurs
              if (newIndex > orderedCompetitions.length) newIndex = orderedCompetitions.length;
              if (oldIndex < newIndex) newIndex -= 1;
              
              final item = orderedCompetitions.removeAt(oldIndex);
              orderedCompetitions.insert(newIndex, item);
              
              final orderedIds = orderedCompetitions.map((c) => c.id).toList();
              ref.read(adminSportsRepositoryProvider).updateCompetitionOrder(orderedIds);
            },
            itemBuilder: (context, index) {
              if (index == orderedCompetitions.length) {
                return Container(
                  key: const ValueKey('amateurs_section'),
                  child: _buildSpecialSection(
                    context,
                    'Amateurs',
                    Icons.groups,
                    () => context.push(
                      '/admin/sports/${sport.id}/amateurs',
                      extra: sport,
                    ),
                  ),
                );
              }
              
              final competition = orderedCompetitions[index];
              return Padding(
                key: ValueKey(competition.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(
                      '/admin/sports/${sport.id}/competitions/${competition.id}/players',
                      extra: {'competition': competition, 'sport': sport},
                    ),
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
                                const Text('Voir les joueurs',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
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
                          const Icon(Icons.drag_handle,
                              color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSpecialSection(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accentGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      if (onTap != null)
                        const Text('Voir les joueurs',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}