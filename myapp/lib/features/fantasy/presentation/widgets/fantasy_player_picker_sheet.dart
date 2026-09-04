import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../core/fantasy_formation.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import 'fantasy_player_pick_card.dart';

/// Ouvre une feuille modale permettant de choisir un joueur pour un poste
/// donné du schéma tactique.
///
/// - [allPlayers] : tous les joueurs fantasy disponibles pour le sport.
/// - [line] : la ligne du poste à pourvoir (gardien / défense / milieu /
///   attaque) ; seuls les joueurs de cette ligne sont proposés.
/// - [excludedPlayerIds] : joueurs déjà placés ailleurs dans l'équipe (ils
///   ne peuvent pas être choisis une deuxième fois), sauf [currentPlayerId].
/// - [currentPlayerId] : joueur déjà présent sur ce poste, le cas échéant
///   (permet de le mettre en avant et de l'exclure de son propre filtre
///   d'exclusion).
///
/// Retourne l'id du joueur choisi, ou `null` si l'utilisateur a fermé la
/// feuille sans choisir.
Future<String?> showFantasyPlayerPickerSheet({
  required BuildContext context,
  required List<FantasyPricedPlayer> allPlayers,
  required FormationLine line,
  required Set<String> excludedPlayerIds,
  String? currentPlayerId,
}) {
  final available = allPlayers.where((p) {
    if (formationLineFor(p.player.position) != line) return false;
    if (p.player.id == currentPlayerId) return true;
    return !excludedPlayerIds.contains(p.player.id);
  }).toList();

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _FantasyPlayerPickerSheet(
      players: available,
      line: line,
      currentPlayerId: currentPlayerId,
    ),
  );
}

class _FantasyPlayerPickerSheet extends StatefulWidget {
  final List<FantasyPricedPlayer> players;
  final FormationLine line;
  final String? currentPlayerId;

  const _FantasyPlayerPickerSheet({
    required this.players,
    required this.line,
    required this.currentPlayerId,
  });

  @override
  State<_FantasyPlayerPickerSheet> createState() =>
      _FantasyPlayerPickerSheetState();
}

class _FantasyPlayerPickerSheetState extends State<_FantasyPlayerPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _lineLabel {
    switch (widget.line) {
      case FormationLine.keeper:
        return 'un gardien';
      case FormationLine.defense:
        return 'un défenseur';
      case FormationLine.midfield:
        return 'un milieu';
      case FormationLine.attack:
        return 'un attaquant';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.players
        : widget.players
            .where((p) => p.player.fullName.toLowerCase().contains(query))
            .toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choisir $_lineLabel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un joueur…',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Aucun joueur disponible pour ce poste.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final priced = visible[index];
                              final isCurrent =
                                  priced.player.id == widget.currentPlayerId;
                              return _PickerPlayerTile(
                                priced: priced,
                                isCurrent: isCurrent,
                                onTap: () =>
                                    Navigator.of(context).pop(priced.player.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickerPlayerTile extends StatelessWidget {
  final FantasyPricedPlayer priced;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PickerPlayerTile({
    required this.priced,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = priced.player;
    final color = positionColor(player.position);

    return Material(
      color: isCurrent
          ? AppTheme.accentGreen.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.accentGreen.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.18),
                backgroundImage: player.profileImageUrl != null
                    ? CachedNetworkImageProvider(player.profileImageUrl!)
                    : null,
                child: player.profileImageUrl == null
                    ? Icon(Icons.person, color: color, size: 20)
                    : null,
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
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priced.cost.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.accentGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}