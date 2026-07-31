import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../coaches/data/models/coach_model.dart';
import '../providers/admin_content_providers.dart';

/// Coachs : liste + filtre sport + CRUD.
class AdminCoachesListScreen extends ConsumerStatefulWidget {
  const AdminCoachesListScreen({super.key});

  @override
  ConsumerState<AdminCoachesListScreen> createState() =>
      _AdminCoachesListScreenState();
}

class _AdminCoachesListScreenState extends ConsumerState<AdminCoachesListScreen> {
  String? _sportId;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, CoachModel coach) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Supprimer ce coach ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '"${coach.fullName}" sera définitivement supprimé.',
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
      await ref.read(adminCoachesRepositoryProvider).deleteCoach(coach.id);
      ref.invalidate(adminCoachesListProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Coach supprimé');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportsAsync = ref.watch(adminSportsListProvider);
    final coachesAsync = ref.watch(adminCoachesListProvider(_sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Gestion des coaches')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentGreen,
        onPressed: () => context.push('/admin/coaches/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: sportsAsync.when(
              data: (sports) => DropdownButtonFormField<String?>(
                initialValue: _sportId,
                dropdownColor: AppTheme.surfaceColor,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Filtrer par sport'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Tous les sports')),
                  ...sports.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.iconEmoji ?? ""} ${s.name}'),
                      )),
                ],
                onChanged: (v) => setState(() => _sportId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: coachesAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accentGreen)),
              error: (e, st) => Center(
                  child: Text(ErrorUtils.friendlyMessage(e),
                      style: const TextStyle(color: AppTheme.textSecondary))),
              data: (coaches) {
                if (coaches.isEmpty) {
                  return const Center(
                    child: Text('Aucun coach pour le moment.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: coaches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final coach = coaches[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppTheme.accentGreen.withValues(alpha: 0.2),
                            backgroundImage: coach.photoUrl != null
                                ? NetworkImage(coach.photoUrl!)
                                : null,
                            child: coach.photoUrl == null
                                ? const Icon(Icons.sports, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(coach.fullName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.textSecondary),
                            onPressed: () => context.push(
                                '/admin/coaches/edit/${coach.id}',
                                extra: coach),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () =>
                                _confirmDelete(context, ref, coach),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}