import 'package:flutter/material.dart';
import '../../core/fantasy_formation.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import 'pitch_player_token.dart';
import 'stadium_pitch_background.dart';

/// Simule un terrain de stade et y dispose l'équipe composée :
/// le capitaine est mis en avant "à la tête" de l'équipe, tout en haut,
/// puis le reste des joueurs sélectionnés est réparti en dessous par ligne
/// (attaque → milieu → défense → gardien), comme une vraie formation.
class FantasyFormationPitch extends StatelessWidget {
  final List<FantasyPricedPlayer> selectedPlayers;
  final String? captainId;
  final double height;

  /// Si renseigné, un tap sur un joueur du terrain le désigne capitaine.
  final ValueChanged<String>? onDesignateCaptain;

  /// Si renseigné, un appui long sur un joueur du terrain le retire de
  /// l'équipe.
  final ValueChanged<String>? onRemovePlayer;

  const FantasyFormationPitch({
    super.key,
    required this.selectedPlayers,
    required this.captainId,
    this.height = 420,
    this.onDesignateCaptain,
    this.onRemovePlayer,
  });

  @override
  Widget build(BuildContext context) {
    final captain = captainId == null
        ? null
        : selectedPlayers.where((p) => p.player.id == captainId).firstOrNull;

    final others = selectedPlayers.where((p) => p.player.id != captainId).toList();

    final byLine = <FormationLine, List<FantasyPricedPlayer>>{
      FormationLine.attack: [],
      FormationLine.midfield: [],
      FormationLine.defense: [],
      FormationLine.keeper: [],
    };
    for (final p in others) {
      byLine[formationLineFor(p.player.position)]!.add(p);
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: StadiumPitchBackground(
        child: Column(
          children: [
            _CaptainSpotlight(
              captain: captain,
              onTap: captain != null && onDesignateCaptain != null
                  ? () => onDesignateCaptain!(captain.player.id)
                  : null,
              onRemove: captain != null && onRemovePlayer != null
                  ? () => onRemovePlayer!(captain.player.id)
                  : null,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                children: [
                  _FormationRow(
                    players: byLine[FormationLine.attack]!,
                    onTap: onDesignateCaptain,
                    onLongPress: onRemovePlayer,
                  ),
                  _FormationRow(
                    players: byLine[FormationLine.midfield]!,
                    onTap: onDesignateCaptain,
                    onLongPress: onRemovePlayer,
                  ),
                  _FormationRow(
                    players: byLine[FormationLine.defense]!,
                    onTap: onDesignateCaptain,
                    onLongPress: onRemovePlayer,
                  ),
                  _FormationRow(
                    players: byLine[FormationLine.keeper]!,
                    onTap: onDesignateCaptain,
                    onLongPress: onRemovePlayer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptainSpotlight extends StatelessWidget {
  final FantasyPricedPlayer? captain;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _CaptainSpotlight({required this.captain, this.onTap, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Column(
        children: [
          Text(
            'CAPITAINE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          if (captain == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Text(
                'Choisis ton capitaine ci-dessous ⭐',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          else
            PitchPlayerToken(
              player: captain!.player,
              isCaptain: true,
              avatarRadius: 32,
              onTap: onTap,
              onLongPress: onRemove,
            ),
        ],
      ),
    );
  }
}

class _FormationRow extends StatelessWidget {
  final List<FantasyPricedPlayer> players;
  final ValueChanged<String>? onTap;
  final ValueChanged<String>? onLongPress;

  const _FormationRow({required this.players, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Réduit la taille des jetons si beaucoup de joueurs partagent
          // la même ligne, pour éviter tout débordement horizontal.
          final maxRadius = players.length <= 4
              ? 24.0
              : (constraints.maxWidth / players.length / 2.4).clamp(14.0, 24.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final p in players)
                PitchPlayerToken(
                  key: ValueKey(p.player.id),
                  player: p.player,
                  avatarRadius: maxRadius,
                  onTap: onTap != null ? () => onTap!(p.player.id) : null,
                  onLongPress: onLongPress != null
                      ? () => onLongPress!(p.player.id)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}