import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/player_with_stats_model.dart';
import '../providers/public_players_provider.dart';

class PublicPlayersListScreen extends ConsumerStatefulWidget {
  final String competitionId;
  final String? sportName;
  final String? competitionName;

  const PublicPlayersListScreen({
    super.key,
    required this.competitionId,
    this.sportName,
    this.competitionName,
  });

  @override
  ConsumerState<PublicPlayersListScreen> createState() =>
      _PublicPlayersListScreenState();
}

class _PublicPlayersListScreenState
    extends ConsumerState<PublicPlayersListScreen> {
  final _searchController = TextEditingController();
  String _filter = 'Tous';

  static const _filters = ['Tous', 'Attaquants', 'Défenseurs', 'Milieux'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(PlayerWithDetails details) {
    final position = (details.player.position ?? '').toUpperCase();
    switch (_filter) {
      case 'Attaquants':
        return position.startsWith('ATT');
      case 'Défenseurs':
        return position.startsWith('DEF');
      case 'Milieux':
        return position.startsWith('MIL');
      default:
        return true;
    }
  }

  bool _matchesSearch(PlayerWithDetails details) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return details.player.fullName.toLowerCase().contains(query);
  }

  /// Convertit un code pays ISO-2 (ex: 'FR') en emoji drapeau.
  /// Renvoie une chaîne vide si `nationality` n'est pas un code à 2 lettres.
  String _flagEmoji(String? nationality) {
    if (nationality == null || nationality.length != 2) return '';
    final code = nationality.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    return String.fromCharCodes(
      code.codeUnits.map((c) => 0x1F1E6 + (c - 65)),
    );
  }

  String _positionLabel(String? position) {
    switch ((position ?? '').toUpperCase()) {
      case 'ATT':
        return 'Attaquant';
      case 'DEF':
        return 'Défenseur';
      case 'MIL':
        return 'Milieu';
      case 'GK':
        return 'Gardien';
      default:
        return position ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync =
        ref.watch(publicPlayersByCompetitionProvider(widget.competitionId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- HEADER ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (widget.sportName ?? 'JOUEURS').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        playersAsync.maybeWhen(
                          data: (players) => Text(
                            '${widget.competitionName ?? ''} - ${players.length} joueurs',
                            style: const TextStyle(
                                color: AppTheme.accentGreen, fontSize: 13),
                          ),
                          orElse: () => Text(
                            widget.competitionName ?? '',
                            style: const TextStyle(
                                color: AppTheme.accentGreen, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- SEARCH BAR ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un joueur...',
                  prefixIcon: const Icon(Icons.search,
                      color: AppTheme.textSecondary),
                  suffixIcon: const Icon(Icons.tune,
                      color: AppTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- FILTRES ----------
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final f = _filters[index];
                  final selected = f == _filter;
                  return InkWell(
                    onTap: () => setState(() => _filter = f),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accentGreen
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ---------- LISTE DES JOUEURS ----------
            Expanded(
              child: playersAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accentGreen),
                ),
                error: (err, st) => Center(
                  child: Text(
                    ErrorUtils.friendlyMessage(err),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                data: (players) {
                  final filtered = players
                      .where((p) => _matchesFilter(p) && _matchesSearch(p))
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun joueur trouvé',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final details = filtered[index];
                      return _PlayerCard(
                        details: details,
                        flagEmoji: _flagEmoji(details.player.nationality),
                        positionLabel:
                            _positionLabel(details.player.position),
                        onTap: () =>
                            context.push('/player/${details.player.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerWithDetails details;
  final String flagEmoji;
  final String positionLabel;
  final VoidCallback onTap;

  const _PlayerCard({
    required this.details,
    required this.flagEmoji,
    required this.positionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = details.player;
    final stats = details.latestStats;

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppTheme.accentGreen.withValues(alpha: 0.2),
                        backgroundImage: player.profileImageUrl != null
                            ? NetworkImage(player.profileImageUrl!)
                            : null,
                        child: player.profileImageUrl == null
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 28)
                            : null,
                      ),
                      if (player.jerseyNumber != null)
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.surfaceColor, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${player.jerseyNumber}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (flagEmoji.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(flagEmoji,
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (player.position != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  positionLabel,
                                  style: const TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (details.teamName != null ||
                                details.age != null)
                              Text(
                                [
                                  if (details.teamName != null)
                                    details.teamName!,
                                  if (details.age != null)
                                    '${details.age} ans',
                                ].join(' · '),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                          ],
                        ),
                        if (stats != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.sports_soccer,
                                  size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text('${stats.goals} buts',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.stadium_outlined,
                                  size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text('${stats.matchesPlayed} matchs',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentGreen),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Voir statistiques →',
                    style: TextStyle(
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}