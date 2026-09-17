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

  Future<void> _toggleSection(BuildContext context, WidgetRef ref, String sectionKey, bool value) async {
    try {
      await ref.read(adminSportsRepositoryProvider).updateSport(sport.id, {
        sectionKey: value,
      });
      ref.invalidate(adminSportsListProvider);
      ref.invalidate(sportsListProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, value ? 'Section activée' : 'Section désactivée');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
      }
    }
  }

  void _showAddMenu(BuildContext context, WidgetRef ref, SportModel currentSport) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ajouter une section', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: AppTheme.accentGreen),
              title: const Text('Compétition Pro (Ligue 1, etc.)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showCompetitionDialog(context, ref);
              },
            ),
            if (!currentSport.hasCoaches)
              ListTile(
                leading: const Icon(Icons.sports, color: AppTheme.accentGreen),
                title: const Text('Activer la section Coachs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSection(context, ref, 'has_coaches', true);
                },
              ),
            if (!currentSport.hasAmateurs)
              ListTile(
                leading: const Icon(Icons.groups, color: AppTheme.accentGreen),
                title: const Text('Activer la section Amateurs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSection(context, ref, 'has_amateurs', true);
                },
              ),
            if (!currentSport.hasAcademies)
              ListTile(
                leading: const Icon(Icons.school, color: AppTheme.accentGreen),
                title: const Text('Activer la section Académies', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSection(context, ref, 'has_academies', true);
                },
              ),
          ],
        ),
      ),
    );
  }

  int _competitionOrder(CompetitionModel competition) {
    final match = RegExp(r'ligue\s*([0-9]+)', caseSensitive: false)
        .firstMatch(competition.name);
    return match != null ? int.parse(match.group(1)!) : 9999;
  }

  int _competitionComparator(CompetitionModel a, CompetitionModel b) {
    final orderA = _competitionOrder(a);
    final orderB = _competitionOrder(b);
    if (orderA != orderB) return orderA.compareTo(orderB);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
            onPressed: () => _showAddMenu(context, ref, currentSport),
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
          final orderedCompetitions = [...competitions]..sort(_competitionComparator);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Compétitions
              for (final competition in orderedCompetitions)
                Padding(
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
                            const Icon(Icons.chevron_right,
                                color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (currentSport.hasAmateurs)
                _buildSpecialSection(
                  context,
                  ref,
                  'Amateurs',
                  Icons.groups,
                  () => _toggleSection(context, ref, 'has_amateurs', false),
                  onTap: () => context.push(
                    '/admin/sports/${sport.id}/amateurs',
                    extra: sport,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpecialSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon,
    VoidCallback onDelete, {
    VoidCallback? onTap,
  }) {
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
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.surfaceColor,
                        title: Text('Désactiver la section $title ?', style: const TextStyle(color: Colors.white)),
                        content: const Text('Cette section ne sera plus affichée sur l\'accueil.', style: TextStyle(color: AppTheme.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Désactiver', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    );
                    if (confirmed == true) onDelete();
                  },
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