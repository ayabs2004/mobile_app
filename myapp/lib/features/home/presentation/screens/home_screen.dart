import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../sports/presentation/providers/sports_provider.dart';
import '../../../sports/data/models/competition_model.dart';
import '../../../sports/data/repositories/sports_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../admin/presentation/providers/current_profile_provider.dart';
import '../../../admin/presentation/providers/admin_stats_provider.dart';
import '../../../players/data/models/player_with_stats_model.dart';
import '../../../players/presentation/providers/public_players_provider.dart';
import '../../../coaches/presentation/providers/coachs_provider.dart';
import '../../../coaches/data/models/coach_model.dart';
import '../../../players/data/models/player_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedSportId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsRepositoryProvider).logEvent(eventType: 'app_open');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sportsAsync = ref.watch(sportsListProvider);
    final userRoleAsync = ref.watch(currentUserRoleProvider);
    final canAccessAdmin = ref.watch(canAccessAdminProvider);

    final displayName = (user?.userMetadata?['full_name'] as String?)
            ?.split(' ')
            .first ??
        'Sportif';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentGreen,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () async => ref.invalidate(sportsListProvider),
          child: CustomScrollView(
            slivers: [
              // ---------- HEADER ----------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => context.push('/account'),
                              borderRadius: BorderRadius.circular(23),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.logoGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person,
                                        color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Bienvenue 👋',
                                            style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12)),
                                        Text('Bonjour, $displayName !',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700),
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (canAccessAdmin)
                            IconButton(
                              icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  color: AppTheme.accentGreen),
                              tooltip: 'Espace admin',
                              onPressed: () => context.push('/admin'),
                            ),
                          _NotificationBell(onTap: () {
                            // TODO: écran notifications
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ---------- SEARCH BAR ----------
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un joueur, une équipe...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.textSecondary),
                        ),
                        onTap: () {
                          // TODO: écran de recherche
                        },
                      ),
                      const SizedBox(height: 24),
                      // ---------- SÉLECTEUR DE SPORT ----------
                      sportsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (sports) {
                          if (sports.isEmpty) return const SizedBox.shrink();
                          _selectedSportId ??= sports.first.id;
                          final selectedSport = sports.firstWhere(
                            (s) => s.id == _selectedSportId,
                            orElse: () => sports.first,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'SPORTS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${sports.length} disciplines',
                                    style: const TextStyle(
                                        color: AppTheme.accentGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 86,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: sports.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final sport = sports[index];
                                    final selected =
                                        sport.id == _selectedSportId;
                                    return _SportChip(
                                      name: sport.name,
                                      emoji: sport.iconEmoji ?? '🏆',
                                      selected: selected,
                                      onTap: () => setState(
                                          () => _selectedSportId = sport.id),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Text(selectedSport.iconEmoji ?? '🏆',
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedSport.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ---------- LIGUES DU SPORT SÉLECTIONNÉ, AVEC LEURS JOUEURS ----------
              if (_selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final competitionsAsync =
                        ref.watch(competitionsBySportProvider(_selectedSportId!));

                    return competitionsAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.accentGreen)),
                        ),
                      ),
                      error: (err, st) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 20),
                          child: Center(
                            child: Text(
                              'Erreur de chargement des compétitions.',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                      data: (competitions) {
                        if (competitions.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 40, horizontal: 20),
                              child: Center(
                                child: Text(
                                  'Aucune compétition disponible pour ce sport.',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                            ),
                          );
                        }

                        final currentSport = sportsAsync.valueOrNull
                            ?.firstWhere((s) => s.id == _selectedSportId);
                        final currentSportName = currentSport?.name ?? '';
                        final currentSportSlug = currentSport?.slug ?? '';

                        // Prob2 fix: inverser l'ordre pour afficher Ligue 1
                        // en premier (display_order le plus élevé = créé en dernier)
                        final orderedCompetitions = competitions.reversed.toList();

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final competition = orderedCompetitions[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 26),
                                  child: _CompetitionSection(
                                    competition: competition,
                                    onSeeAll: () => context.push(
                                      '/sport/$currentSportSlug/competition/${competition.id}/players',
                                      extra: {
                                        'sportName': currentSportName,
                                        'competitionName': competition.name,
                                      },
                                    ),
                                  ),
                                );
                              },
                              childCount: orderedCompetitions.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // ---------- COACHS DU SPORT SÉLECTIONNÉ (indépendant des compétitions) ----------
              // Prob1 fix: la section n'est affichée que si des coachs existent
              if (_selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final coachesAsync = ref.watch(
                        publicCoachesBySportProvider(_selectedSportId!));
                    return coachesAsync.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (coaches) {
                        if (coaches.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          sliver: SliverToBoxAdapter(
                            child: _SectionShell(
                              icon: Icons.sports,
                              label: 'Coachs',
                              child: _CoachesList(
                                sportId: _selectedSportId!,
                                onSeeAll: () {
                                  final sport = sportsAsync.valueOrNull
                                      ?.firstWhere((s) => s.id == _selectedSportId);
                                  context.push('/sport/${sport?.slug}/coachs', extra: {
                                    'sportId': _selectedSportId,
                                    'sportName': sport?.name,
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // ---------- AMATEURS DU SPORT SÉLECTIONNÉ ----------
              // Prob1 fix: la section n'est affichée que si des amateurs existent
              if (_selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final amateursAsync = ref.watch(
                        publicAmateurPlayersBySportProvider(_selectedSportId!));
                    return amateursAsync.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (players) {
                        if (players.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                        const maxShown = 2;
                        final shown = players.take(maxShown).toList();
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          sliver: SliverToBoxAdapter(
                            child: _SectionShell(
                              icon: Icons.emoji_events,
                              label: 'Amateurs',
                              child: Column(
                                children: [
                                  for (final p in shown)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _AmateurRow(
                                        player: p,
                                        onTap: () =>
                                            context.push('/player/${p.id}'),
                                      ),
                                    ),
                                  if (players.length > maxShown)
                                    _SeeAllLink(
                                      count: players.length,
                                      label: 'amateurs',
                                      onTap: () {
                                        final sport = sportsAsync.valueOrNull
                                            ?.firstWhere((s) =>
                                                s.id == _selectedSportId);
                                        context.push(
                                            '/sport/${sport?.slug}/amateurs',
                                            extra: {
                                              'sportId': _selectedSportId,
                                              'sportName': sport?.name,
                                            });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String name;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _SportChip({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentGreen.withValues(alpha: 0.12)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.accentGreen
                : Colors.white.withValues(alpha: 0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    selected ? AppTheme.accentGreen : AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section d'une ligue/compétition : icône + barre verticale + nom vertical,
/// puis la liste des joueurs de cette compétition.
class _CompetitionSection extends ConsumerWidget {
  final CompetitionModel competition;
  final VoidCallback onSeeAll;

  const _CompetitionSection({
    required this.competition,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- Icône + nom de la ligue en vertical ----------
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.logoGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 2,
                            color:
                                AppTheme.accentGreen.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          competition.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ---------- Contenu : joueurs ----------
          Expanded(
            child: _PlayersList(
              competitionId: competition.id,
              onSeeAll: onSeeAll,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coquille réutilisable pour les sections "Coachs" et "Amateurs" :
/// icône + barre verticale + nom vertical, calquée sur _CompetitionSection.
class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SectionShell({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.logoGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 2,
                            color:
                                AppTheme.accentGreen.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Liste des joueurs (max 2) d'une compétition, avec lien "voir tout".
class _PlayersList extends ConsumerWidget {
  final String competitionId;
  final VoidCallback onSeeAll;
  static const int _maxShown = 2;

  const _PlayersList({
    required this.competitionId,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync =
        ref.watch(publicPlayersByCompetitionProvider(competitionId));

    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentGreen,
          ),
        ),
      ),
      error: (err, st) => Text(
        ErrorUtils.friendlyMessage(err),
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      data: (players) {
        if (players.isEmpty) {
          return const Text(
            'Aucun joueur pour le moment.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          );
        }
        final shown = players.take(_maxShown).toList();
        return Column(
          children: [
            for (final p in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlayerRow(
                  playerWithDetails: p,
                  onTap: () => context.push('/player/${p.player.id}'),
                ),
              ),
            if (players.length > _maxShown)
              _SeeAllLink(
                count: players.length,
                label: 'joueurs',
                onTap: onSeeAll,
              ),
          ],
        );
      },
    );
  }
}

/// Liste des coachs (max 2) d'un sport, avec lien "voir tout".
class _CoachesList extends ConsumerWidget {
  final String sportId;
  final VoidCallback onSeeAll;
  static const int _maxShown = 2;

  const _CoachesList({
    required this.sportId,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(publicCoachesBySportProvider(sportId));

    return coachesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentGreen,
          ),
        ),
      ),
      error: (err, st) => Text(
        ErrorUtils.friendlyMessage(err),
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      data: (coaches) {
        if (coaches.isEmpty) {
          return const Text(
            'Aucun coach pour le moment.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          );
        }
        final shown = coaches.take(_maxShown).toList();
        return Column(
          children: [
            for (final c in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CoachRow(
                  coach: c,
                  onTap: () => context.push('/coach/${c.id}'),
                ),
              ),
            if (coaches.length > _maxShown)
              _SeeAllLink(
                count: coaches.length,
                label: 'coachs',
                onTap: onSeeAll,
              ),
          ],
        );
      },
    );
  }
}

/// Lien "Voir les N ..." réutilisé pour joueurs, coachs et amateurs.
class _SeeAllLink extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _SeeAllLink({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              'Voir les $count $label',
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios,
                size: 10, color: AppTheme.accentGreen),
          ],
        ),
      ),
    );
  }
}

/// Palette tournante utilisée pour colorer les avatars (déterministe).
const List<Color> _avatarPalette = [
  Color(0xFFE23744), // rouge
  Color(0xFF2E7D32), // vert
  Color(0xFF1565C0), // bleu
  Color(0xFF6A1B9A), // violet
  Color(0xFFEF6C00), // orange
  Color(0xFF00838F), // teal
];

Color _colorForId(String id) {
  final index =
      id.codeUnits.fold<int>(0, (sum, c) => sum + c) % _avatarPalette.length;
  return _avatarPalette[index];
}

String _initialsFromName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Une ligne "joueur" : avatar coloré (initiales) — nom + club + n° maillot
/// — "Voir le profil" — chevron.
class _PlayerRow extends StatelessWidget {
  final PlayerWithDetails playerWithDetails;
  final VoidCallback onTap;

  const _PlayerRow({
    required this.playerWithDetails,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = playerWithDetails.player;
    final avatarColor = _colorForId(player.id);

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: avatarColor,
                backgroundImage: player.profileImageUrl != null
                    ? NetworkImage(player.profileImageUrl!)
                    : null,
                child: player.profileImageUrl == null
                    ? Text(
                        _initialsFromName(player.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (playerWithDetails.teamName != null)
                          Flexible(
                            child: Text(
                              playerWithDetails.teamName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (player.jerseyNumber != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#${player.jerseyNumber}',
                            style: const TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Voir le profil',
                      style: TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne "coach", calquée sur _PlayerRow.
class _CoachRow extends StatelessWidget {
  final CoachModel coach;
  final VoidCallback onTap;

  const _CoachRow({
    required this.coach,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = _colorForId(coach.id);

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: avatarColor,
                backgroundImage: coach.photoUrl != null
                    ? NetworkImage(coach.photoUrl!)
                    : null,
                child: coach.photoUrl == null
                    ? Text(
                        _initialsFromName(coach.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (coach.yearsExperience != null)
                      Text(
                        '${coach.yearsExperience} ans d\'expérience',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Voir le profil',
                      style: TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne "joueur amateur", calquée sur _PlayerRow (sans stats détaillées).
class _AmateurRow extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onTap;

  const _AmateurRow({
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = _colorForId(player.id);

    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: avatarColor,
                backgroundImage: player.profileImageUrl != null
                    ? NetworkImage(player.profileImageUrl!)
                    : null,
                child: player.profileImageUrl == null
                    ? Text(
                        _initialsFromName(player.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (player.teamName != null)
                          Flexible(
                            child: Text(
                              player.teamName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (player.jerseyNumber != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#${player.jerseyNumber}',
                            style: const TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Voir le profil',
                      style: TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 22),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}