import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../players/data/models/player_model.dart';
import '../providers/admin_players_provider.dart';
import '../providers/admin_content_providers.dart';

/// Joueurs ACADÉMIE : liste + recherche + filtre sport + CRUD.
class AdminAcademiePlayersListScreen extends ConsumerStatefulWidget {
  const AdminAcademiePlayersListScreen({super.key});

  @override
  ConsumerState<AdminAcademiePlayersListScreen> createState() =>
      _AdminAcademiePlayersListScreenState();
}

class _AdminAcademiePlayersListScreenState
    extends ConsumerState<AdminAcademiePlayersListScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _sportId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, PlayerModel player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Supprimer ce joueur ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Cette action est irréversible pour "${player.fullName}".',
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
      await ref.read(adminPlayersRepositoryProvider).deletePlayer(player.id);
      ref.invalidate(adminAcademiePlayersProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Joueur supprimé');
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
    final playersAsync = ref.watch(
      adminAcademiePlayersProvider(
          AdminPlayersFilter(sportId: _sportId, search: _search)),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Joueurs académie')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentGreen,
        tooltip: 'Ajouter un joueur académie',
        onPressed: () => context.push('/admin/academies/new', extra: {
          'sportId': _sportId,
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un joueur académie...',
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: AppTheme.textSecondary),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _search = '';
                        }),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
            child: playersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accentGreen),
              ),
              error: (err, st) => Center(
                child: Text(ErrorUtils.friendlyMessage(err),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              data: (players) {
                if (players.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isEmpty
                          ? 'Aucun joueur académie pour le moment.'
                          : 'Aucun joueur trouvé pour "$_search".',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final player = players[index];
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
                            backgroundImage: player.profileImageUrl != null
                                ? NetworkImage(player.profileImageUrl!)
                                : null,
                            child: player.profileImageUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player.fullName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                if (player.niveau != null || player.position != null || player.teamName != null)
                                  Row(
                                    children: [
                                      if (player.niveau != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            player.niveau!,
                                            style: const TextStyle(
                                              color: AppTheme.accentGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (player.position != null || player.teamName != null)
                                        Flexible(
                                          child: Text(
                                            [
                                              if (player.position != null)
                                                player.position!,
                                              if (player.teamName != null)
                                                player.teamName!,
                                            ].join(' · '),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.textSecondary),
                            onPressed: () => context.push(
                              '/admin/academies/edit/${player.id}',
                              extra: player,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () =>
                                _confirmDelete(context, ref, player),
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
