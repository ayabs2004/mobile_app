import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/fantasy_player_pricing_model.dart';

String positionShortLabel(String? position) {
  switch ((position ?? '').toUpperCase()) {
    case 'GK':
      return 'GB';
    case 'DEF':
      return 'DEF';
    case 'MIL':
    case 'MID':
      return 'MIL';
    case 'ATT':
      return 'ATT';
    default:
      return (position ?? '').isEmpty ? '—' : position!;
  }
}

Color positionColor(String? position) {
  switch ((position ?? '').toUpperCase()) {
    case 'GK':
      return const Color(0xFFF2A93B);
    case 'DEF':
      return const Color(0xFF4C8DFF);
    case 'MIL':
    case 'MID':
      return const Color(0xFF00D05A);
    case 'ATT':
      return const Color(0xFFFF5C7A);
    default:
      return AppTheme.textSecondary;
  }
}

/// Carte "réaliste" pour choisir un joueur dans la liste de composition :
/// pastille de poste colorée, photo, coût, et étoile pour le capitaine.
class FantasyPlayerPickCard extends StatelessWidget {
  final FantasyPricedPlayer priced;
  final bool isSelected;
  final bool isCaptain;
  final bool disabled;
  final VoidCallback onToggle;
  final VoidCallback onSetCaptain;

  const FantasyPlayerPickCard({
    super.key,
    required this.priced,
    required this.isSelected,
    required this.isCaptain,
    required this.onToggle,
    required this.onSetCaptain,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = priced.player;
    final color = positionColor(player.position);

    return Opacity(
      opacity: disabled && !isSelected ? 0.4 : 1,
      child: Material(
        color: isSelected
            ? AppTheme.accentGreen.withValues(alpha: 0.10)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: disabled && !isSelected ? null : onToggle,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentGreen.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.06),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withValues(alpha: 0.18),
                      backgroundImage: player.profileImageUrl != null
                          ? CachedNetworkImageProvider(player.profileImageUrl!)
                          : null,
                      child: player.profileImageUrl == null
                          ? Icon(Icons.person, color: color, size: 22)
                          : null,
                    ),
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          positionShortLabel(player.position),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
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
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      priced.cost.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isSelected)
                      GestureDetector(
                        onTap: onSetCaptain,
                        child: Icon(
                          isCaptain ? Icons.star : Icons.star_border,
                          color: isCaptain ? Colors.amber : Colors.white38,
                          size: 22,
                        ),
                      )
                    else
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 22,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}