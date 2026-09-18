import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../players/data/models/player_model.dart';

/// Jeton d'un joueur affiché sur la pelouse : photo (ou maillot par défaut),
/// numéro, nom et éventuellement le brassard de capitaine.
class PitchPlayerToken extends StatelessWidget {
  final PlayerModel player;
  final bool isCaptain;
  final bool highlighted;
  final double avatarRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? badge;

  const PitchPlayerToken({
    super.key,
    required this.player,
    this.isCaptain = false,
    this.highlighted = false,
    this.avatarRadius = 26,
    this.onTap,
    this.onLongPress,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final initials = player.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarRadius * 2 + 6,
                height: avatarRadius * 2 + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCaptain
                        ? Colors.amber
                        : (highlighted
                            ? AppTheme.accentGreen
                            : Colors.white.withValues(alpha: 0.5)),
                    width: isCaptain ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: player.profileImageUrl != null
                      ? CachedNetworkImageProvider(player.profileImageUrl!)
                      : null,
                  child: player.profileImageUrl == null
                      ? Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: avatarRadius * 0.6,
                          ),
                        )
                      : null,
                ),
              ),
              if (player.jerseyNumber != null)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${player.jerseyNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (isCaptain)
                Positioned(
                  top: -6,
                  left: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, color: Colors.black, size: 12),
                  ),
                ),
              if (badge != null)
                Positioned(top: -4, right: -4, child: badge!),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(maxWidth: avatarRadius * 2.6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player.fullName.split(' ').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}