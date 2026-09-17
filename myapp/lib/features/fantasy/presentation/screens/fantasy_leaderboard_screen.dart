import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/fantasy_round_model.dart';
import '../../data/models/fantasy_team_model.dart';
import '../providers/fantasy_provider.dart';

class FantasyLeaderboardScreen extends ConsumerStatefulWidget {
  final String? sportId;
  final String? sportName;

  const FantasyLeaderboardScreen({super.key, this.sportId, this.sportName});

  @override
  ConsumerState<FantasyLeaderboardScreen> createState() =>
      _FantasyLeaderboardScreenState();
}

class _FantasyLeaderboardScreenState
    extends ConsumerState<FantasyLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sport = widget.sportId;
    if (sport == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Classement')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ouvre le fantasy depuis la page d\'un sport (foot ou hand).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.sportName != null
            ? 'Classement · ${widget.sportName}'
            : 'Classement'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Round en cours'),
            Tab(text: 'Général'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RoundLeaderboardTab(sportId: sport),
          _GeneralLeaderboardTab(sportId: sport),
        ],
      ),
    );
  }
}

/// Classement du round actuellement ouvert pour ce sport.
class _RoundLeaderboardTab extends ConsumerWidget {
  final String sportId;

  const _RoundLeaderboardTab({required this.sportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundAsync = ref.watch(currentFantasyRoundProvider(sportId));

    return roundAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          ErrorUtils.friendlyMessage(e, context: 'le chargement du round'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      data: (round) {
        if (round == null) {
          return const Center(
            child: Text(
              'Aucun round fantasy actif pour le moment.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final leaderboardAsync = ref.watch(fantasyLeaderboardProvider(round.id));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(fantasyLeaderboardProvider(round.id));
            await ref.read(fantasyLeaderboardProvider(round.id).future);
          },
          child: leaderboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                ErrorUtils.friendlyMessage(e, context: 'le chargement du classement'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 12),
                    _RoundBanner(round: round),
                    const SizedBox(height: 60),
                    const Center(
                      child: Text(
                        'Aucun classement disponible pour l\'instant.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _RoundBanner(round: round);
                  }
                  final entry = entries[index - 1];
                  final rank = index;
                  final isTopThree = rank <= 3;

                  return Card(
                    color: AppTheme.surfaceColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isTopThree ? _rankColor(rank) : AppTheme.backgroundColor,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: isTopThree ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        entry.userName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '${entry.totalPoints} pts',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Bandeau rappelant le round affiché et son statut (ouvert/clos).
class _RoundBanner extends StatelessWidget {
  final FantasyRoundModel round;

  const _RoundBanner({required this.round});

  @override
  Widget build(BuildContext context) {
    final bool isOpen = round.isOpen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              round.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOpen
                  ? AppTheme.accentGreen.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isOpen ? 'En cours' : 'Clos',
              style: TextStyle(
                color: isOpen ? AppTheme.accentGreen : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Classement général : cumul des points sur tous les rounds du sport.
class _GeneralLeaderboardTab extends ConsumerWidget {
  final String sportId;

  const _GeneralLeaderboardTab({required this.sportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(fantasyGeneralLeaderboardProvider(sportId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fantasyGeneralLeaderboardProvider(sportId));
        await ref.read(fantasyGeneralLeaderboardProvider(sportId).future);
      },
      child: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement du classement général'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'Aucun classement général disponible pour l\'instant.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final FantasyGeneralLeaderboardEntry entry = entries[index];
              final rank = index + 1;
              final isTopThree = rank <= 3;

              return Card(
                color: AppTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isTopThree ? _rankColor(rank) : AppTheme.backgroundColor,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: isTopThree ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.userName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${entry.roundsPlayed} round${entry.roundsPlayed > 1 ? 's' : ''} joué${entry.roundsPlayed > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Text(
                    '${entry.totalPoints} pts',
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
}

Color _rankColor(int rank) {
  switch (rank) {
    case 1:
      return Colors.amber;
    case 2:
      return Colors.grey.shade300;
    case 3:
      return Colors.brown.shade300;
    default:
      return AppTheme.backgroundColor;
  }
}