import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../core/fantasy_formation.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import '../providers/fantasy_provider.dart';
import '../widgets/fantasy_formation_pitch.dart';
import '../widgets/fantasy_formation_slots_pitch.dart';
import '../widgets/fantasy_player_pick_card.dart';
import '../widgets/fantasy_player_picker_sheet.dart';
import '../widgets/pitch_player_token.dart';

class FantasyTeamBuilderScreen extends ConsumerStatefulWidget {
  final String? sportId;
  final String? sportName;

  const FantasyTeamBuilderScreen({super.key, this.sportId, this.sportName});

  @override
  ConsumerState<FantasyTeamBuilderScreen> createState() =>
      _FantasyTeamBuilderScreenState();
}

class _FantasyTeamBuilderScreenState
    extends ConsumerState<FantasyTeamBuilderScreen> {
  bool _initialized = false;
  bool _saving = false;
  String _positionFilter = 'Tous';
  final _searchController = TextEditingController();

  static const _positionFilters = ['Tous', 'GK', 'DEF', 'MIL', 'ATT'];
  static const _positionFilterLabels = {
    'Tous': 'Tous',
    'GK': 'Gardiens',
    'DEF': 'Défenseurs',
    'MIL': 'Milieux',
    'ATT': 'Attaquants',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _totalCost(List<FantasyPricedPlayer> allPlayers, Set<String> selectedIds) {
    return allPlayers
        .where((p) => selectedIds.contains(p.player.id))
        .fold(0.0, (sum, p) => sum + p.cost);
  }

  Future<void> _save(String sportId) async {
    final selectedIds = ref.read(fantasyTeamBuilderProvider);
    final captainId = ref.read(fantasyCaptainProvider);
    final formation = ref.read(fantasyFormationProvider);
    final slotAssignments = ref.read(fantasyFormationSlotsProvider);

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orangeAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sélectionne au moins un joueur.',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(fantasyRepositoryProvider).saveTeam(
            sportId: sportId,
            playerIds: selectedIds.toList(),
            captainPlayerId: captainId,
            formation: formation == kFreeFormationKey ? null : formation,
            slotAssignments: slotAssignments,
          );
      if (!mounted) return;
      ref.invalidate(myFantasyTeamProvider(sportId));
      ref.invalidate(fantasyLeaderboardProvider(sportId));
      ref.invalidate(fantasyScoreHistoryProvider(sportId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.accentGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Équipe enregistrée avec succès !',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ErrorUtils.friendlyMessage(e, context: "l'enregistrement de l'équipe"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _matchesFilter(FantasyPricedPlayer p) {
    if (_positionFilter == 'Tous') return true;
    return (p.player.position ?? '').toUpperCase().startsWith(_positionFilter);
  }

  bool _matchesSearch(FantasyPricedPlayer p) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return p.player.fullName.toLowerCase().contains(query);
  }

  /// Change le schéma tactique. Passer à un schéma fixe (ou d'un schéma fixe
  /// à un autre) réinitialise la composition en cours, car les postes du
  /// nouveau schéma ne correspondent plus à l'ancienne sélection.
  Future<void> _chooseFormation(String key) async {
    final current = ref.read(fantasyFormationProvider);
    if (key == current) return;

    final hasSelection = ref.read(fantasyTeamBuilderProvider).isNotEmpty;
    final targetIsTemplate = key != kFreeFormationKey;

    if (targetIsTemplate && hasSelection) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Changer de formation ?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Ta sélection actuelle sera réinitialisée pour appliquer ce nouveau schéma.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    ref.read(fantasyFormationProvider.notifier).state = key;

    if (targetIsTemplate) {
      final template = kFormationTemplates.firstWhere((f) => f.key == key);
      ref.read(fantasyFormationSlotsProvider.notifier).resetForTemplate(template);
      ref.read(fantasyTeamBuilderProvider.notifier).reset(const []);
      ref.read(fantasyCaptainProvider.notifier).state = null;
    } else {
      ref.read(fantasyFormationSlotsProvider.notifier).clear();
    }
  }

  Future<void> _onTapEmptySlot(
    FormationSlot slot,
    List<FantasyPricedPlayer> allPlayers,
  ) async {
    final assignedIds = ref.read(fantasyFormationSlotsProvider).values.where((id) => id != null).cast<String>().toSet();
    final chosenId = await showFantasyPlayerPickerSheet(
      context: context,
      allPlayers: allPlayers,
      line: slot.line,
      excludedPlayerIds: assignedIds,
      currentPlayerId: null,
    );
    if (chosenId == null) return;
    
    final selectedIds = ref.read(fantasyTeamBuilderProvider);
    if (!selectedIds.contains(chosenId)) {
      if (widget.sportId != null) {
        final settings = ref.read(fantasySportSettingsProvider(widget.sportId!)).valueOrNull;
        if (settings != null && selectedIds.length >= settings.maxPlayers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.black),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Effectif complet. Retire un joueur avant d\'en ajouter un nouveau.',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          return;
        }
      }
      ref.read(fantasyTeamBuilderProvider.notifier).toggle(chosenId);
    }
    
    ref.read(fantasyFormationSlotsProvider.notifier).assign(slot.id, chosenId);
  }

  void _onClearSlot(String slotId) {
    final playerId = ref.read(fantasyFormationSlotsProvider)[slotId];
    if (playerId == null) return;
    ref.read(fantasyFormationSlotsProvider.notifier).clearSlot(slotId);
    ref.read(fantasyTeamBuilderProvider.notifier).toggle(playerId);
    if (ref.read(fantasyCaptainProvider) == playerId) {
      ref.read(fantasyCaptainProvider.notifier).state = null;
    }
  }

  /// Utilisé par la liste de joueurs en bas d'écran quand un schéma fixe
  /// est actif : place le joueur tapé sur le premier poste encore libre
  /// de sa ligne, ou le retire s'il est déjà sur le terrain.
  void _onToggleFromListWithTemplate(
    FantasyPricedPlayer priced,
    FormationTemplate template,
  ) {
    final selectedIds = ref.read(fantasyTeamBuilderProvider);
    final playerId = priced.player.id;

    if (selectedIds.contains(playerId)) {
      ref.read(fantasyFormationSlotsProvider.notifier).clearPlayer(playerId);
      ref.read(fantasyTeamBuilderProvider.notifier).toggle(playerId);
      if (ref.read(fantasyCaptainProvider) == playerId) {
        ref.read(fantasyCaptainProvider.notifier).state = null;
      }
      return;
    }

    if (widget.sportId != null) {
      final settings = ref.read(fantasySportSettingsProvider(widget.sportId!)).valueOrNull;
      if (settings != null && selectedIds.length >= settings.maxPlayers) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orangeAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.black),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Effectif complet.',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    final line = formationLineFor(priced.player.position);
    final slots = ref.read(fantasyFormationSlotsProvider);
    final freeSlot = template.slots
        .where((s) => s.line == line && slots[s.id] == null)
        .firstOrNull;

    if (freeSlot == null) {
      if (widget.sportId != null) {
        final settings = ref.read(fantasySportSettingsProvider(widget.sportId!)).valueOrNull;
        if (settings != null && selectedIds.length < settings.maxPlayers) {
          // Ajout direct sur le banc
          ref.read(fantasyTeamBuilderProvider.notifier).toggle(playerId);
          return;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orangeAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucun poste libre à cette ligne. L\'effectif est peut-être déjà complet.',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    ref.read(fantasyFormationSlotsProvider.notifier).assign(freeSlot.id, playerId);
    ref.read(fantasyTeamBuilderProvider.notifier).toggle(playerId);
  }

  @override
  Widget build(BuildContext context) {
    final sportId = widget.sportId;

    if (sportId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Compose ton équipe')),
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

    final settingsAsync = ref.watch(fantasySportSettingsProvider(sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.sportName != null
              ? 'Compose ton équipe · ${widget.sportName}'
              : 'Compose ton équipe',
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(e, context: 'le chargement des réglages'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (settings) {
          final playersAsync =
              ref.watch(fantasyPricedPlayersProvider(widget.sportId));
          final myTeamAsync = ref.watch(myFantasyTeamProvider(sportId));

          return playersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                ErrorUtils.friendlyMessage(e, context: 'le chargement des joueurs'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (allPlayers) {
              // Pré-remplit la sélection avec l'équipe existante (une seule fois).
              myTeamAsync.whenData((team) {
                if (!_initialized && team != null) {
                  _initialized = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(fantasyTeamBuilderProvider.notifier)
                        .reset(team.playerIds);
                    ref.read(fantasyCaptainProvider.notifier).state =
                        team.captainPlayerId;

                    // Restaure aussi le schéma tactique et les postes, si
                    // l'équipe avait été enregistrée avec un schéma fixe.
                    final formation = team.formation;
                    if (formation != null && formation != kFreeFormationKey) {
                      ref.read(fantasyFormationProvider.notifier).state =
                          formation;
                      ref
                          .read(fantasyFormationSlotsProvider.notifier)
                          .restore(team.slotAssignments);
                    }
                  });
                }
              });

              final selectedIds = ref.watch(fantasyTeamBuilderProvider);
              final captainId = ref.watch(fantasyCaptainProvider);
              final spent = _totalCost(allPlayers, selectedIds);
              final remaining = settings.budget - spent;
              final overBudget = remaining < 0;
              final overCount = selectedIds.length > settings.maxPlayers;
              final squadFull = selectedIds.length >= settings.maxPlayers;

              final byId = <String, FantasyPricedPlayer>{
                for (final p in allPlayers) p.player.id: p,
              };
              final selectedPlayers = selectedIds
                  .where(byId.containsKey)
                  .map((id) => byId[id]!)
                  .toList();

              final visiblePlayers = allPlayers
                  .where(_matchesFilter)
                  .where(_matchesSearch)
                  .toList();

              final formationKey = ref.watch(fantasyFormationProvider);
              final availableFormations = availableFormationsFor(settings.maxPlayers);
              final isFreeFormation = formationKey == kFreeFormationKey;
              final currentTemplate = isFreeFormation
                  ? null
                  : kFormationTemplates.firstWhere((f) => f.key == formationKey);
              final slotAssignments = ref.watch(fantasyFormationSlotsProvider);

              final benchPlayers = <FantasyPricedPlayer>[];
              if (currentTemplate != null) {
                final assignedIds = slotAssignments.values.where((id) => id != null).cast<String>().toSet();
                benchPlayers.addAll(selectedPlayers.where((p) => !assignedIds.contains(p.player.id)));
              }

              // --- Sections fixes en haut de l'écran (statut, tactique,
              // terrain, recherche, filtres). Regroupées ici pour être
              // insérées dans le CustomScrollView ci-dessous : tout défile
              // ensemble avec la liste des joueurs, ce qui évite tout
              // débordement quelle que soit la taille de l'écran.
              final topSections = [
                  // --- Barre de statut (budget / effectif) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppTheme.surfaceColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatChip(
                          icon: Icons.groups_rounded,
                          label: '${selectedIds.length} / ${settings.maxPlayers} joueurs',
                          color: overCount ? Colors.redAccent : Colors.white70,
                        ),
                        _StatChip(
                          icon: Icons.savings_rounded,
                          label: 'Budget : ${remaining.toStringAsFixed(1)}',
                          color: overBudget ? Colors.redAccent : AppTheme.accentGreen,
                        ),
                      ],
                    ),
                  ),

                  // --- Choix du schéma tactique (libre / 4-4-2 / 4-3-3…) ---
                  if (availableFormations.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: availableFormations.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final key = index == 0
                              ? kFreeFormationKey
                              : availableFormations[index - 1].key;
                          final label =
                              index == 0 ? 'Libre' : availableFormations[index - 1].label;
                          final selected = formationKey == key;
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) => _chooseFormation(key),
                            backgroundColor: AppTheme.surfaceColor,
                            selectedColor: AppTheme.accentGreen.withValues(alpha: 0.25),
                            labelStyle: TextStyle(
                              color: selected ? AppTheme.accentGreen : Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.accentGreen
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        },
                      ),
                    ),

                  // --- Le "stade" : terrain simulé avec capitaine en tête ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: currentTemplate != null
                        ? FantasyFormationSlotsPitch(
                            template: currentTemplate,
                            slotAssignments: slotAssignments,
                            allPlayers: allPlayers,
                            captainId: captainId,
                            onTapEmptySlot: (slot) =>
                                _onTapEmptySlot(slot, allPlayers),
                            onDesignateCaptain: (id) => ref
                                .read(fantasyCaptainProvider.notifier)
                                .state = id,
                            onClearSlot: _onClearSlot,
                          )
                        : FantasyFormationPitch(
                            selectedPlayers: selectedPlayers,
                            captainId: captainId,
                            onDesignateCaptain: (id) =>
                                ref.read(fantasyCaptainProvider.notifier).state = id,
                            onRemovePlayer: (id) =>
                                ref.read(fantasyTeamBuilderProvider.notifier).toggle(id),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      currentTemplate != null
                          ? (captainId == null
                              ? 'Touche un poste vide pour choisir un joueur, puis l\'étoile ⭐ pour le nommer capitaine.'
                              : 'Appui long sur un joueur du terrain pour le placer sur le banc.')
                          : (captainId == null
                              ? 'Touche l\'étoile ⭐ d\'un joueur sélectionné pour le nommer capitaine.'
                              : 'Appui long sur un joueur du terrain pour le retirer de l\'équipe.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                    ),
                  ),
                  
                  // --- Banc des remplaçants ---
                  if (currentTemplate != null && settings.maxPlayers > 11)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Banc des remplaçants',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            if (benchPlayers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Aucun remplaçant sélectionné',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: benchPlayers.map((p) => PitchPlayerToken(
                                  key: ValueKey('bench_${p.player.id}'),
                                  player: p.player,
                                  avatarRadius: 20,
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Colors.white12),

                  // --- Recherche + filtres de poste ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _positionFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final key = _positionFilters[index];
                        final selected = _positionFilter == key;
                        return ChoiceChip(
                          label: Text(_positionFilterLabels[key]!),
                          selected: selected,
                          onSelected: (_) => setState(() => _positionFilter = key),
                          backgroundColor: AppTheme.surfaceColor,
                          selectedColor: AppTheme.accentGreen.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: selected ? AppTheme.accentGreen : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppTheme.accentGreen
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
              ];

              // --- Liste des joueurs disponibles (sous forme de slivers, pour
              // pouvoir défiler dans le même scroll view que les sections
              // du dessus : plus de hauteur fixe qui pourrait déborder). ---
              final Widget playerListSliver;
              if (allPlayers.isEmpty) {
                playerListSliver = const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun joueur fantasy disponible pour ce sport.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                );
              } else if (visiblePlayers.isEmpty) {
                playerListSliver = const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Aucun joueur ne correspond à ta recherche.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              } else {
                playerListSliver = SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: visiblePlayers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final priced = visiblePlayers[index];
                      final isSelected = selectedIds.contains(priced.player.id);
                      final isCaptain = captainId == priced.player.id;

                      return FantasyPlayerPickCard(
                        priced: priced,
                        isSelected: isSelected,
                        isCaptain: isCaptain,
                        disabled: squadFull && !isSelected,
                        onToggle: () => currentTemplate != null
                            ? _onToggleFromListWithTemplate(priced, currentTemplate)
                            : ref
                                .read(fantasyTeamBuilderProvider.notifier)
                                .toggle(priced.player.id),
                        onSetCaptain: () => ref
                            .read(fantasyCaptainProvider.notifier)
                            .state = priced.player.id,
                      );
                    },
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: Column(children: topSections)),
                        playerListSliver,
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_saving || overBudget || overCount)
                              ? null
                              : () => _save(sportId),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Enregistrer mon équipe'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
