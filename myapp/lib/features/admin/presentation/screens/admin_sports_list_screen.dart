import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../sports/data/models/sport_model.dart';
import '../providers/admin_content_providers.dart';

class AdminSportsListScreen extends ConsumerWidget {
  const AdminSportsListScreen({super.key});

  Future<void> _confirmAndDeleteSport(
      BuildContext context, WidgetRef ref, SportModel sport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Supprimer ce sport ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '"${sport.name}" ainsi que toutes ses compétitions et joueurs '
          'seront définitivement supprimés. Cette action est irréversible.',
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
      await ref.read(adminSportsRepositoryProvider).deleteSport(sport.id);
      ref.invalidate(adminSportsListProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Sport supprimé');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
      }
    }
  }

  Future<void> _showSportDialog(
    BuildContext context,
    WidgetRef ref, {
    SportModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emojiController =
        TextEditingController(text: existing?.iconEmoji ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          existing == null ? 'Nouveau sport' : 'Modifier le sport',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nom (ex: Rugby)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Emoji (ex: 🏉)'),
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
                await repo.createSport({
                  'name': nameController.text.trim(),
                  'slug': slug,
                  'icon_emoji': emojiController.text.trim().isEmpty
                      ? null
                      : emojiController.text.trim(),
                  'display_order': 99,
                });
              } else {
                await repo.updateSport(existing.id, {
                  'name': nameController.text.trim(),
                  'icon_emoji': emojiController.text.trim().isEmpty
                      ? null
                      : emojiController.text.trim(),
                });
              }
              ref.invalidate(adminSportsListProvider);
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau sport',
            onPressed: () => _showSportDialog(context, ref),
          ),
        ],
      ),
      body: sportsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        error: (e, st) => Center(
            child: Text(ErrorUtils.friendlyMessage(e),
                style: const TextStyle(color: AppTheme.textSecondary))),
        data: (sports) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: sports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final sport = sports[index];
            return Material(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(
                  '/admin/sports/${sport.id}/competitions',
                  extra: sport,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text('${sport.iconEmoji ?? ""} ${sport.name}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary),
                        tooltip: 'Modifier le sport',
                        onPressed: () =>
                            _showSportDialog(context, ref, existing: sport),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Supprimer le sport',
                        onPressed: () =>
                            _confirmAndDeleteSport(context, ref, sport),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary),
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