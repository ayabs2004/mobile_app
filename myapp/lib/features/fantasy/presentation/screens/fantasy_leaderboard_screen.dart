import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
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
            Tab(text: 'Classement'),
            Tab(text: 'Mes essais'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LiveLeaderboardTab(sportId: sport),
          _MyScoreHistoryTab(sportId: sport),
        ],
      ),
    );
  }
}

/// Classement live du sport : recalculé à chaque lecture (plus de round),
/// donc reflète toujours l'état actuel des équipes et des stats.
class _LiveLeaderboardTab extends ConsumerWidget {
  final String sportId;

  const _LiveLeaderboardTab({required this.sportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(fantasyLeaderboardProvider(sportId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fantasyLeaderboardProvider(sportId));
        await ref.read(fantasyLeaderboardProvider(sportId).future);
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
              children: const [
                SizedBox(height: 80),
                Center(
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
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
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

/// Historique perso : score + rang capturés à chaque sauvegarde d'équipe.
/// Montre comment le classement de l'utilisateur a varié d'un essai à
/// l'autre, sans notion de round.
class _MyScoreHistoryTab extends ConsumerWidget {
  final String sportId;

  const _MyScoreHistoryTab({required this.sportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(fantasyScoreHistoryProvider(sportId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fantasyScoreHistoryProvider(sportId));
        await ref.read(fantasyScoreHistoryProvider(sportId).future);
      },
      child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: "le chargement de l'historique"),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    "Compose et enregistre une équipe pour voir tes essais ici.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          }

          // Le plus récent en premier.
          final reversed = snapshots.reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reversed.length,
            itemBuilder: (context, index) {
              final snap = reversed[index];
              final previous =
                  index + 1 < reversed.length ? reversed[index + 1] : null;
              final delta = previous == null ? null : previous.rank - snap.rank;

              return Card(
                color: AppTheme.surfaceColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.backgroundColor,
                    child: Text(
                      '#${snap.rank}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    '${snap.totalPoints} pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(snap.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: delta == null
                      ? null
                      : _RankDeltaBadge(delta: delta),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm à $hh:$min';
  }
}

/// Petit badge indiquant si le rang s'est amélioré (▲), dégradé (▼) ou
/// n'a pas bougé (–) par rapport à l'essai précédent.
class _RankDeltaBadge extends StatelessWidget {
  final int delta;

  const _RankDeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return const Text('–', style: TextStyle(color: Colors.white54));
    }
    final improved = delta > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          improved ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: improved ? AppTheme.accentGreen : Colors.redAccent,
        ),
        Text(
          '${delta.abs()}',
          style: TextStyle(
            color: improved ? AppTheme.accentGreen : Colors.redAccent,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ],
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
