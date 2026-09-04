import 'package:flutter/material.dart';
import '../../core/fantasy_formation.dart';
import '../../data/models/fantasy_player_pricing_model.dart';
import 'pitch_player_token.dart';
import 'stadium_pitch_background.dart';

/// Simule un terrain de stade pour un **schéma tactique fixe** (4-4-2, 4-3-3…) :
/// chaque poste du schéma est un rond sur la pelouse, vide ou occupé.
/// Le capitaine est mis en avant tout en haut, puis les postes sont
/// répartis en dessous ligne par ligne (attaque → milieu → défense →
/// gardien), exactement comme la composition d'une vraie équipe.
///
/// - Tap sur un poste **vide** -> ouvre le choix d'un joueur pour ce poste.
/// - Tap sur un poste **occupé** -> désigne ce joueur capitaine.
/// - Appui long sur un poste occupé -> libère le poste.
class FantasyFormationSlotsPitch extends StatelessWidget {
  final FormationTemplate template;

  /// Poste -> joueur choisi (ou null si le poste est vide).
  final Map<String, String?> slotAssignments;

  /// Tous les joueurs disponibles, pour résoudre un id -> FantasyPricedPlayer.
  final List<FantasyPricedPlayer> allPlayers;

  final String? captainId;
  final double height;

  final ValueChanged<FormationSlot> onTapEmptySlot;
  final ValueChanged<String> onDesignateCaptain;
  final ValueChanged<String> onClearSlot;

  const FantasyFormationSlotsPitch({
    super.key,
    required this.template,
    required this.slotAssignments,
    required this.allPlayers,
    required this.captainId,
    required this.onTapEmptySlot,
    required this.onDesignateCaptain,
    required this.onClearSlot,
    this.height = 460,
  });

  @override
  Widget build(BuildContext context) {
    final byId = <String, FantasyPricedPlayer>{
      for (final p in allPlayers) p.player.id: p,
    };

    FantasyPricedPlayer? playerFor(FormationSlot slot) {
      final id = slotAssignments[slot.id];
      if (id == null) return null;
      return byId[id];
    }

    final slotsByLine = <FormationLine, List<FormationSlot>>{
      FormationLine.attack: [],
      FormationLine.midfield: [],
      FormationLine.defense: [],
      FormationLine.keeper: [],
    };
    FormationSlot? captainSlot;
    for (final slot in template.slots) {
      slotsByLine[slot.line]!.add(slot);
      final id = slotAssignments[slot.id];
      if (id != null && id == captainId) captainSlot = slot;
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: StadiumPitchBackground(
        child: Column(
          children: [
            _CaptainSlotSpotlight(
              slot: captainSlot,
              player: captainSlot != null ? playerFor(captainSlot) : null,
              onTap: captainSlot != null
                  ? () => onDesignateCaptain(slotAssignments[captainSlot!.id]!)
                  : null,
              onRemove: captainSlot != null
                  ? () => onClearSlot(captainSlot!.id)
                  : null,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                children: [
                  _SlotRow(
                    slots: slotsByLine[FormationLine.attack]!,
                    playerFor: playerFor,
                    captainId: captainId,
                    onTapEmptySlot: onTapEmptySlot,
                    onDesignateCaptain: onDesignateCaptain,
                    onClearSlot: onClearSlot,
                  ),
                  _SlotRow(
                    slots: slotsByLine[FormationLine.midfield]!,
                    playerFor: playerFor,
                    captainId: captainId,
                    onTapEmptySlot: onTapEmptySlot,
                    onDesignateCaptain: onDesignateCaptain,
                    onClearSlot: onClearSlot,
                  ),
                  _SlotRow(
                    slots: slotsByLine[FormationLine.defense]!,
                    playerFor: playerFor,
                    captainId: captainId,
                    onTapEmptySlot: onTapEmptySlot,
                    onDesignateCaptain: onDesignateCaptain,
                    onClearSlot: onClearSlot,
                  ),
                  _SlotRow(
                    slots: slotsByLine[FormationLine.keeper]!,
                    playerFor: playerFor,
                    captainId: captainId,
                    onTapEmptySlot: onTapEmptySlot,
                    onDesignateCaptain: onDesignateCaptain,
                    onClearSlot: onClearSlot,
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

class _CaptainSlotSpotlight extends StatelessWidget {
  final FormationSlot? slot;
  final FantasyPricedPlayer? player;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _CaptainSlotSpotlight({
    required this.slot,
    required this.player,
    this.onTap,
    this.onRemove,
  });

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
          if (player == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Touche l\'étoile ⭐ d\'un joueur placé pour le nommer capitaine',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          else
            PitchPlayerToken(
              player: player!.player,
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

class _SlotRow extends StatelessWidget {
  final List<FormationSlot> slots;
  final FantasyPricedPlayer? Function(FormationSlot) playerFor;
  final String? captainId;
  final ValueChanged<FormationSlot> onTapEmptySlot;
  final ValueChanged<String> onDesignateCaptain;
  final ValueChanged<String> onClearSlot;

  const _SlotRow({
    required this.slots,
    required this.playerFor,
    required this.captainId,
    required this.onTapEmptySlot,
    required this.onDesignateCaptain,
    required this.onClearSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxRadius = slots.length <= 4
              ? 24.0
              : (constraints.maxWidth / slots.length / 2.4).clamp(14.0, 24.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final slot in slots)
                _SlotToken(
                  key: ValueKey(slot.id),
                  slot: slot,
                  priced: playerFor(slot),
                  isCaptain: playerFor(slot)?.player.id == captainId,
                  avatarRadius: maxRadius,
                  onTapEmpty: () => onTapEmptySlot(slot),
                  onDesignateCaptain: onDesignateCaptain,
                  onClearSlot: onClearSlot,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotToken extends StatelessWidget {
  final FormationSlot slot;
  final FantasyPricedPlayer? priced;
  final bool isCaptain;
  final double avatarRadius;
  final VoidCallback onTapEmpty;
  final ValueChanged<String> onDesignateCaptain;
  final ValueChanged<String> onClearSlot;

  const _SlotToken({
    super.key,
    required this.slot,
    required this.priced,
    required this.isCaptain,
    required this.avatarRadius,
    required this.onTapEmpty,
    required this.onDesignateCaptain,
    required this.onClearSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (priced == null) {
      return _EmptySlotToken(
        line: slot.line,
        avatarRadius: avatarRadius,
        onTap: onTapEmpty,
      );
    }

    return PitchPlayerToken(
      player: priced!.player,
      isCaptain: isCaptain,
      avatarRadius: avatarRadius,
      onTap: () => onDesignateCaptain(priced!.player.id),
      onLongPress: () => onClearSlot(slot.id),
    );
  }
}

/// Rond en pointillés représentant un poste non encore pourvu du schéma.
class _EmptySlotToken extends StatelessWidget {
  final FormationLine line;
  final double avatarRadius;
  final VoidCallback onTap;

  const _EmptySlotToken({
    required this.line,
    required this.avatarRadius,
    required this.onTap,
  });

  String get _label {
    switch (line) {
      case FormationLine.keeper:
        return 'GB';
      case FormationLine.defense:
        return 'DEF';
      case FormationLine.midfield:
        return 'MIL';
      case FormationLine.attack:
        return 'ATT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = avatarRadius * 2 + 6;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.6,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.85),
                size: avatarRadius * 0.9,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(maxWidth: avatarRadius * 2.6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}