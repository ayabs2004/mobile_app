import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../sports/presentation/providers/sports_provider.dart';
import '../../../sports/data/models/competition_model.dart';
import '../../../sports/data/models/sport_model.dart';
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
import '../../../fantasy/data/models/fantasy_sport_settings_model.dart';
import '../../../fantasy/presentation/providers/fantasy_provider.dart';
import '../../../fantasy/core/fantasy_sport_utils.dart';

class HomeSearchResult {
  final List<PlayerModel> players;
  final List<CoachModel> coaches;
  final List<CompetitionModel> competitions;

  const HomeSearchResult({
    this.players = const [],
    this.coaches = const [],
    this.competitions = const [],
  });

  bool get isEmpty => players.isEmpty && coaches.isEmpty && competitions.isEmpty;
}

final homeSearchProvider =
    FutureProvider.autoDispose.family<HomeSearchResult, String>((ref, query) async {
  final clean = query.trim();
  if (clean.isEmpty) return const HomeSearchResult();

  final playersRes = await SupabaseConfig.client
      .from('players_public')
      .select()
      .or('full_name.ilike.%$clean%,team_name.ilike.%$clean%')
      .eq('is_active', true)
      .limit(10);

  final coachesRes = await SupabaseConfig.client
      .from('coaches_public')
      .select()
      .ilike('full_name', '%$clean%')
      .limit(10);

  final competitionsRes = await SupabaseConfig.client
      .from('competitions')
      .select()
      .ilike('name', '%$clean%')
      .limit(5);

  final players =
      (playersRes as List).map((j) => PlayerModel.fromJson(j)).toList();
  final coaches =
      (coachesRes as List).map((j) => CoachModel.fromJson(j)).toList();
  final competitions =
      (competitionsRes as List).map((j) => CompetitionModel.fromJson(j)).toList();

  return HomeSearchResult(
    players: players,
    coaches: coaches,
    competitions: competitions,
  );
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedSportId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Le fantasy n'existe que pour le foot et le hand : on regarde le sport
    // actuellement sélectionné dans le sélecteur pour savoir si la bannière
    // doit apparaître, et pour filtrer les joueurs proposés dans l'équipe.
    final sportsList = sportsAsync.valueOrNull;
    SportModel? selectedSportForFantasy;
    if (sportsList != null && sportsList.isNotEmpty) {
      selectedSportForFantasy = sportsList.firstWhere(
        (s) => s.id == _selectedSportId,
        orElse: () => sportsList.first,
      );
    }
    final showFantasy = selectedSportForFantasy != null &&
        isFantasySport(selectedSportForFantasy);

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
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ---------- SEARCH BAR ----------
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un joueur, un coach, une compétition...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppTheme.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 24),
                      // ---------- SÉLECTEUR DE SPORT ----------
                      if (_searchQuery.trim().isEmpty)
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

              // ---------- FANTASY (bannière d'accès) ----------
              // Masquée pendant une recherche, et réservée aux sports foot
              // et hand : le module fantasy n'existe pas pour les autres.
              if (_searchQuery.trim().isEmpty && showFantasy)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                  sliver: SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final settingsAsync = ref.watch(
                          fantasySportSettingsProvider(
                              selectedSportForFantasy!.id),
                        );
                        return settingsAsync.when(
                          loading: () => const _FantasyBanner(
                            settings: null,
                            loading: true,
                            sportId: null,
                            sportName: null,
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (settings) => _FantasyBanner(
                            settings: settings,
                            loading: false,
                            sportId: selectedSportForFantasy!.id,
                            sportName: selectedSportForFantasy.name,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // ---------- RÉSULTATS DE RECHERCHE (JOUEURS UNIQUEMENT) ----------
              if (_searchQuery.trim().isNotEmpty)
                Consumer(
                  builder: (context, ref, _) {
                    final searchAsync =
                        ref.watch(homeSearchProvider(_searchQuery.trim()));

                    return searchAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ),
                      ),
                      error: (err, st) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 20),
                          child: Center(
                            child: Text(
                              ErrorUtils.friendlyMessage(err),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                      data: (results) {
                        if (results.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 40, horizontal: 20),
                              child: Center(
                                child: Text(
                                  'Aucun joueur trouvé pour "${_searchQuery.trim()}".',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              const SizedBox(height: 10),
                              if (results.players.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'JOUEURS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${results.players.length} trouvé(s)',
                                      style: const TextStyle(
                                        color: AppTheme.accentGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final player in results.players)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _PlayerRow(
                                      playerWithDetails: PlayerWithDetails(
                                        player: player,
                                        teamName: player.teamName,
                                      ),
                                      onTap: () =>
                                          context.push('/player/${player.id}'),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],
                              if (results.coaches.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'COACHS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${results.coaches.length} trouvé(s)',
                                      style: const TextStyle(
                                        color: AppTheme.accentGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final coach in results.coaches)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CoachRow(
                                      coach: coach,
                                      onTap: () =>
                                          context.push('/coach/${coach.id}'),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],
                              if (results.competitions.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'COMPÉTITIONS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${results.competitions.length} trouvée(s)',
                                      style: const TextStyle(
                                        color: AppTheme.accentGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (final comp in results.competitions)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.emoji_events,
                                          color: AppTheme.accentGreen),
                                      title: Text(comp.name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          color: AppTheme.textSecondary,
                                          size: 14),
                                      onTap: () {
                                        context.push(
                                          '/sport/sport/competition/${comp.id}/players',
                                          extra: {
                                            'sportName': '',
                                            'competitionName': comp.name,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ]),
                          ),
                        );
                      },
                    );
                  },
                ),

              // ---------- LIGUES DU SPORT SÉLECTIONNÉ, AVEC LEURS JOUEURS ----------
              if (_searchQuery.trim().isEmpty && _selectedSportId != null)
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
              // Masquée pendant une recherche
              if (_searchQuery.trim().isEmpty && _selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final currentSport = sportsAsync.valueOrNull?.firstWhere((s) => s.id == _selectedSportId);
                    if (currentSport == null || !currentSport.hasCoaches) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final coachesAsync = ref.watch(
                        publicCoachesBySportProvider(_selectedSportId!));
                    return coachesAsync.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (coaches) {
                        if (coaches.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          sliver: SliverToBoxAdapter(
                            child: _SectionShell(
                              icon: Icons.sports,
                              label: 'Coachs',
                              child: Column(
                                children: [
                                  for (final c in coaches.take(2))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _CoachRow(
                                        coach: c,
                                        onTap: () =>
                                            context.push('/coach/${c.id}'),
                                      ),
                                    ),
                                  if (coaches.length > 2)
                                    _SeeAllLink(
                                      count: coaches.length,
                                      label: 'coachs',
                                      onTap: () => context.push(
                                          '/sport/${currentSport.slug}/coachs',
                                          extra: {
                                            'sportId': _selectedSportId,
                                            'sportName': currentSport.name,
                                          }),
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

              // ---------- AMATEURS DU SPORT SÉLECTIONNÉ ----------
              // Masquée pendant une recherche
              if (_searchQuery.trim().isEmpty && _selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final currentSport = sportsAsync.valueOrNull?.firstWhere((s) => s.id == _selectedSportId);
                    if (currentSport == null || !currentSport.hasAmateurs) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final amateursAsync = ref.watch(
                        publicAmateurPlayersBySportProvider(_selectedSportId!));
                    return amateursAsync.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (players) {
                        if (players.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          sliver: SliverToBoxAdapter(
                            child: _SectionShell(
                              icon: Icons.emoji_events,
                              label: 'Amateurs',
                              child: Column(
                                children: [
                                  for (final p in players.take(2))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _AmateurRow(
                                        player: p,
                                        onTap: () =>
                                            context.push('/player/${p.id}'),
                                      ),
                                    ),
                                  if (players.length > 2)
                                    _SeeAllLink(
                                      count: players.length,
                                      label: 'amateurs',
                                      onTap: () => context.push(
                                          '/sport/${currentSport.slug}/amateurs',
                                          extra: {
                                            'sportId': _selectedSportId,
                                            'sportName': currentSport.name,
                                          }),
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

              // ---------- ACADÉMIES DU SPORT SÉLECTIONNÉ ----------
              // Masquée pendant une recherche
              if (_searchQuery.trim().isEmpty && _selectedSportId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final currentSport = sportsAsync.valueOrNull?.firstWhere((s) => s.id == _selectedSportId);
                    if (currentSport == null || !currentSport.hasAcademies) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    final academiesAsync = ref.watch(
                        publicAcademiePlayersBySportProvider(_selectedSportId!));
                    return academiesAsync.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (players) {
                        if (players.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          sliver: SliverToBoxAdapter(
                            child: _SectionShell(
                              icon: Icons.school,
                              label: 'Académies',
                              child: Column(
                                children: [
                                  for (final p in players.take(2))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _AcademieRow(
                                        player: p,
                                        onTap: () =>
                                            context.push('/player/${p.id}'),
                                      ),
                                    ),
                                  if (players.length > 2)
                                    _SeeAllLink(
                                      count: players.length,
                                      label: 'académies',
                                      onTap: () => context.push(
                                          '/sport/${currentSport.slug}/academies',
                                          extra: {
                                            'sportId': _selectedSportId,
                                            'sportName': currentSport.name,
                                          }),
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

/// Bannière d'accès au module Fantasy, affichée en haut du Home.
/// Toujours affichée pour les sports concernés (foot/hand).
class _FantasyBanner extends StatelessWidget {
  final FantasySportSettingsModel? settings;
  final bool loading;
  final String? sportId;
  final String? sportName;

  const _FantasyBanner({
    required this.settings,
    required this.loading,
    required this.sportId,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accentGreen,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.logoGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FANTASY LEAGUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sportName != null ? 'Fantasy $sportName' : 'Compose ton équipe !',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FantasyActionChip(
                  label: 'Composer',
                  icon: Icons.add_task,
                  onTap: () => context.push('/fantasy', extra: {
                    'sportId': sportId,
                    'sportName': sportName,
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FantasyActionChip(
                  label: 'Mon équipe',
                  icon: Icons.groups,
                  onTap: () => context.push('/fantasy/team', extra: {
                    'sportId': sportId,
                    'sportName': sportName,
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FantasyActionChip(
                  label: 'Classement',
                  icon: Icons.leaderboard,
                  onTap: () => context.push('/fantasy/leaderboard', extra: {
                    'sportId': sportId,
                    'sportName': sportName,
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FantasyActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FantasyActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
    final playersAsync =
        ref.watch(publicPlayersByCompetitionProvider(competition.id));

    return playersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (players) {
        if (players.isEmpty) {
          return const SizedBox.shrink();
        }
        
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
      },
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
          return const SizedBox.shrink();
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
          return const SizedBox.shrink();
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

/// Une ligne "joueur académie", calquée sur _AmateurRow avec le niveau en badge.
class _AcademieRow extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onTap;

  const _AcademieRow({
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
                        if (player.niveau != null)
                          Container(
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
                        if (player.niveau != null && player.position != null)
                          const SizedBox(width: 6),
                        if (player.position != null)
                          Flexible(
                            child: Text(
                              player.position!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
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