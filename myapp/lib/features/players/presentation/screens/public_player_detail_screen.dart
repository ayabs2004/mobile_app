import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/video_cache_manager.dart';
import '../../../../core/utils/video_url_resolver.dart';
import '../../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../data/models/player_model.dart';
import '../../data/models/player_with_stats_model.dart';
import '../providers/public_players_provider.dart';

Widget _mediaCaptionOverlay(String caption, {double fontSize = 13}) {
  return Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Text(
        caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.25,
        ),
      ),
    ),
  );
}

class PublicPlayerDetailScreen extends ConsumerStatefulWidget {
  final String playerId;

  const PublicPlayerDetailScreen({
    super.key,
    required this.playerId,
  });

  @override
  ConsumerState<PublicPlayerDetailScreen> createState() =>
      _PublicPlayerDetailScreenState();
}

class _PublicPlayerDetailScreenState
    extends ConsumerState<PublicPlayerDetailScreen> {
  List<PlayerMediaItem> _mediaItems = [];
  bool _isLoadingMedia = true;
  late final String _scopeKey = 'player:${widget.playerId}';

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    VideoCacheManager.clearScope(_scopeKey);
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      final response = await SupabaseConfig.client
          .from('media')
          .select()
          .eq('entity_type', 'player')
          .eq('entity_id', widget.playerId)
          .order('is_cover', ascending: false)
          .order('display_order')
          .order('created_at');

      if (!mounted) return;
      setState(() {
        _mediaItems = (response as List)
            .map((json) => PlayerMediaItem.fromJson(json))
            .toList();
        _isLoadingMedia = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMedia = false);
      }
    }
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
    final detailsAsync =
        ref.watch(publicPlayerDetailProvider(widget.playerId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: detailsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (err, st) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(err),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (details) {
          final player = details.player;
          final heroImageUrl =
              player.coverImageUrl ?? player.profileImageUrl;
          final imageMedia = _mediaItems
              .where((m) =>
                  m.mediaType == 'image' &&
                  m.url != player.profileImageUrl &&
                  m.url != player.coverImageUrl)
              .toList();
          final videoMedia =
              _mediaItems.where((m) => m.mediaType == 'video').toList();

          return CustomScrollView(
            slivers: [
              // ── AppBar hero ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppTheme.surfaceColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (heroImageUrl != null)
                        CachedNetworkImage(
                          imageUrl: heroImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.surfaceColor,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.accentGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.surfaceColor,
                            child: const Icon(Icons.sports_soccer,
                                size: 80,
                                color: AppTheme.textSecondary),
                          ),
                        )
                      else
                        Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(Icons.sports_soccer,
                              size: 80, color: AppTheme.textSecondary),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppTheme.backgroundColor
                                  .withValues(alpha: 0.8),
                              AppTheme.backgroundColor,
                            ],
                            stops: const [0.5, 0.8, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  AppTheme.accentGreen.withValues(alpha: 0.2),
                              backgroundImage:
                                  player.profileImageUrl != null
                                      ? CachedNetworkImageProvider(
                                          player.profileImageUrl!)
                                      : null,
                              child: player.profileImageUrl == null
                                  ? const Icon(Icons.person,
                                      size: 40, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (player.position != null)
                                        Text(
                                          _positionLabel(player.position),
                                          style: const TextStyle(
                                            color: AppTheme.accentGreen,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (player.position != null &&
                                          details.teamName != null)
                                        const Text(
                                          '  ·  ',
                                          style: TextStyle(
                                              color:
                                                  AppTheme.textSecondary,
                                              fontSize: 16),
                                        ),
                                      if (details.teamName != null)
                                        Flexible(
                                          child: Text(
                                            details.teamName!,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color:
                                                  AppTheme.textSecondary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bloc 1 : infos, stats, photos ────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(player, details),
                      if (details.latestStats != null) ...[
                        const SizedBox(height: 20),
                        _buildStatsSection(details.latestStats!),
                      ],
                      if (imageMedia.isNotEmpty ||
                          videoMedia.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Médias',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (imageMedia.isNotEmpty) ...[
                          const Text('Photos',
                              style: TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              imageMedia.length,
                              (index) => _PhotoThumbnail(
                                media: imageMedia[index],
                                allImageMedia: imageMedia,
                                index: index,
                              ),
                            ),
                          ),
                        ],
                        if (videoMedia.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Vidéos',
                              style: TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // ── Bloc 2 : vidéos virtualisées ─────────────────────────
              if (videoMedia.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList.builder(
                    itemCount: videoMedia.length,
                    itemBuilder: (context, index) {
                      final currentMedia = videoMedia[index];
                      final hasCaption = currentMedia.caption != null &&
                          currentMedia.caption!.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasCaption)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  currentMedia.caption!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            _VideoPlayerCard(
                              media: currentMedia,
                              scopeKey: _scopeKey,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // ── Bloc 3 : biographie ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (player.biography != null &&
                          player.biography!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Biographie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          player.biography!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(
      PlayerModel player, PlayerWithDetails details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          if (player.type == 'academie' && player.niveau != null) ...[
            _buildInfoRow(
                Icons.school_outlined, 'Niveau', player.niveau!),
            const Divider(color: Colors.white12, height: 24),
          ],
          if (player.position != null) ...[
            _buildInfoRow(Icons.sports_outlined, 'Poste',
                _positionLabel(player.position)),
            const Divider(color: Colors.white12, height: 24),
          ],
          if (details.teamName != null) ...[
            _buildInfoRow(
                Icons.shield_outlined, 'Équipe', details.teamName!),
            const Divider(color: Colors.white12, height: 24),
          ],
          _buildInfoRow(Icons.numbers, 'Numéro',
              player.jerseyNumber?.toString() ?? 'N/A'),
          const Divider(color: Colors.white12, height: 24),
          if (details.age != null) ...[
            _buildInfoRow(
                Icons.cake_outlined, 'Âge', '${details.age} ans'),
            const Divider(color: Colors.white12, height: 24),
          ],
          _buildInfoRow(Icons.flag_outlined, 'Nationalité',
              player.nationality ?? 'N/A'),
          if (player.heightCm != null) ...[
            const Divider(color: Colors.white12, height: 24),
            _buildInfoRow(
                Icons.height, 'Taille', '${player.heightCm} cm'),
          ],
          if (player.weightKg != null) ...[
            const Divider(color: Colors.white12, height: 24),
            _buildInfoRow(Icons.fitness_center, 'Poids',
                '${player.weightKg} kg'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(PlayerStatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // ── Score global calculé ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: AppTheme.accentGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  stats.scoreDisplay,
                  style: const TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Score',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(Icons.stadium_outlined,
                    '${stats.matchesPlayed}', 'Matchs'),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(
                    Icons.sports_soccer, '${stats.goals}', 'Buts'),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(Icons.assistant_outlined,
                    '${stats.assists}', 'Passes'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(Icons.square_rounded,
                    '${stats.yellowCards}', 'Cartons J.',
                    iconColor: const Color(0xFFF5C518)),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(Icons.square_rounded,
                    '${stats.redCards}', 'Cartons R.',
                    iconColor: const Color(0xFFE53935)),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(Icons.timer_outlined,
                    '${stats.minutesPlayed}', 'Minutes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label,
      {Color? iconColor}) {
    return Column(
      children: [
        Icon(icon, color: iconColor ?? AppTheme.accentGreen, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentGreen, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo thumbnail – tap opens fullscreen gallery
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final PlayerMediaItem media;
  final List<PlayerMediaItem> allImageMedia;
  final int index;

  const _PhotoThumbnail({
    required this.media,
    required this.allImageMedia,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final hasCaption =
        media.caption != null && media.caption!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        FullscreenPhotoViewer.open(
          context,
          imageUrls: allImageMedia.map((m) => m.url).toList(),
          captions: allImageMedia.map((m) => m.caption).toList(),
          initialIndex: index,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 120,
          height: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'player_photo_$index',
                child: CachedNetworkImage(
                  imageUrl: media.url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppTheme.surfaceColor),
                  errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image,
                      color: AppTheme.textSecondary),
                ),
              ),
              if (hasCaption)
                _mediaCaptionOverlay(media.caption!, fontSize: 11),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video router
// ─────────────────────────────────────────────────────────────────────────────

class _VideoPlayerCard extends StatelessWidget {
  final PlayerMediaItem media;
  final String scopeKey;

  const _VideoPlayerCard(
      {required this.media, required this.scopeKey});

  @override
  Widget build(BuildContext context) {
    final youtubeVideoId =
        VideoUrlResolver.extractYoutubeVideoId(media.url);
    if (youtubeVideoId != null) {
      return _YoutubeThumbnailCard(
        videoId: youtubeVideoId,
        originalUrl: media.url,
        caption: media.caption,
      );
    }

    final source = VideoUrlResolver.resolve(media.url);

    if (source.isEmbed) {
      return _EmbedVideoCard(
        embedUrl: source.url,
        originalUrl: media.url,
        cardKey: 'embed-${media.url}-$scopeKey',
        caption: media.caption,
      );
    }

    return _DirectVideoPlayerCard(media: media, scopeKey: scopeKey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouTube thumbnail card
// ─────────────────────────────────────────────────────────────────────────────

class _YoutubeThumbnailCard extends StatelessWidget {
  final String videoId;
  final String originalUrl;
  final String? caption;

  const _YoutubeThumbnailCard({
    required this.videoId,
    required this.originalUrl,
    this.caption,
  });

  Future<void> _openYoutube() async {
    final uri = Uri.tryParse(originalUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return GestureDetector(
      onTap: _openYoutube,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppTheme.surfaceColor),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.surfaceColor,
                  child: const Icon(Icons.smart_display_outlined,
                      size: 56, color: AppTheme.textSecondary),
                ),
              ),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Direct video player card (media_kit)
// ─────────────────────────────────────────────────────────────────────────────

class _DirectVideoPlayerCard extends StatefulWidget {
  final PlayerMediaItem media;
  final String scopeKey;

  const _DirectVideoPlayerCard(
      {required this.media, required this.scopeKey});

  @override
  State<_DirectVideoPlayerCard> createState() =>
      _DirectVideoPlayerCardState();
}

class _DirectVideoPlayerCardState
    extends State<_DirectVideoPlayerCard> {
  VideoController? _controller;
  bool _isInitializing = false;
  bool _hasError = false;
  bool _hasAttemptedLoad = false;
  String? _errorMessage;

  late final String _visibilityKey =
      'video-${widget.media.url}-${widget.scopeKey}';

  @override
  void dispose() {
    if (_controller != null) {
      VideoCacheManager.releaseController(widget.media.url,
          scope: widget.scopeKey);
    }
    super.dispose();
  }

  String _describeVideoError(Object error) {
    debugPrint('Video init failed: $error');
    final message = error.toString().toLowerCase();

    if (message.contains('formatexception') ||
        message.contains('invalid url') ||
        message.contains('url is empty')) {
      return 'L\u2019URL de la vidéo est invalide ou vide.';
    }
    if (message.contains('recognize file format')) {
      return 'Ce lien ne pointe pas vers un fichier vidéo lisible directement.';
    }
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection')) {
      return 'La vidéo est inaccessible sur le réseau.';
    }
    if (message.contains('délai') || message.contains('timeout')) {
      return 'La vidéo met trop de temps à charger.';
    }
    return 'La lecture de cette vidéo a échoué.';
  }

  Future<void> _openInBrowser() async {
    final normalizedUrl = widget.media.url.trim();
    if (normalizedUrl.isEmpty) return;
    final parsedUri = Uri.tryParse(normalizedUrl);
    if (parsedUri == null) return;
    await launchUrl(parsedUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _initializeVideo() async {
    if (_controller != null || _isInitializing) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _hasAttemptedLoad = true;
      _errorMessage = null;
    });

    try {
      final normalizedUrl = widget.media.url.trim();
      if (normalizedUrl.isEmpty) {
        throw const FormatException(
            'L\u2019URL de la vidéo est vide.');
      }
      final parsedUri = Uri.tryParse(normalizedUrl);
      if (parsedUri == null ||
          (!parsedUri.hasScheme || !parsedUri.hasAuthority)) {
        throw const FormatException(
            'L\u2019URL de la vidéo est invalide.');
      }

      final controller = await VideoCacheManager.getController(
          normalizedUrl,
          scope: widget.scopeKey);

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _hasError = false;
      });

      try {
        await controller.player.play();
      } catch (error) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _hasError = false;
            _errorMessage =
                'La lecture a échoué sans bloquer l\u2019affichage.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = _describeVideoError(error);
        });
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_controller == null) return;
    if (info.visibleFraction > 0.05) return;

    VideoCacheManager.releaseController(widget.media.url,
        scope: widget.scopeKey);
    if (mounted) {
      setState(() {
        _controller = null;
        _hasAttemptedLoad = false;
        _hasError = false;
      });
    }
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentGreen.withValues(alpha: 0.25),
            AppTheme.surfaceColor,
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBackground() {
    final isError = _hasError && _hasAttemptedLoad;
    final thumbnailUrl = widget.media.thumbnailUrl;
    final hasThumbnail =
        thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumbnail && !isError)
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildGradientFallback(),
            errorWidget: (context, url, error) =>
                _buildGradientFallback(),
          )
        else
          _buildGradientFallback(),
        if (hasThumbnail && !isError)
          Container(color: Colors.black.withValues(alpha: 0.25)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError
                    ? Icons.play_disabled
                    : Icons.play_circle_fill,
                size: 56,
                color: isError
                    ? Colors.white70
                    : (hasThumbnail
                        ? Colors.white
                        : AppTheme.accentGreen),
              ),
              if (!hasThumbnail && !isError) ...[
                const SizedBox(height: 10),
                const Text(
                  'Appuyez pour lire',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prévisualisation vidéo',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              if (isError) ...[
                const SizedBox(height: 10),
                const Text(
                  'Lecture impossible',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ??
                      'Le lecteur ne peut pas charger cette vidéo ici.',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label:
                      const Text('Ouvrir dans le navigateur'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentGreen),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_visibilityKey),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _controller == null ? _initializeVideo : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null)
                  MaterialVideoControlsTheme(
                    normal: MaterialVideoControlsThemeData(
                      seekBarHeight: 4,
                      seekBarMargin: const EdgeInsets.fromLTRB(
                          12, 0, 12, 36),
                      seekBarThumbColor: AppTheme.accentGreen,
                      seekBarPositionColor: AppTheme.accentGreen,
                      seekBarBufferColor: Colors.white24,
                      bottomButtonBarMargin:
                          const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      buttonBarButtonSize: 26,
                      buttonBarButtonColor: Colors.white,
                    ),
                    fullscreen: MaterialVideoControlsThemeData(
                      seekBarHeight: 5,
                      seekBarThumbColor: AppTheme.accentGreen,
                      seekBarPositionColor: AppTheme.accentGreen,
                    ),
                    child: Video(controller: _controller!),
                  )
                else if (_isInitializing)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: AppTheme.accentGreen),
                        SizedBox(height: 8),
                        Text('Chargement...',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                else
                  _buildPlaceholderBackground(),
                if (_controller != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Lecture',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embed video card (WebView – Facebook, Instagram, TikTok, Drive)
// ─────────────────────────────────────────────────────────────────────────────

class _EmbedVideoCard extends StatefulWidget {
  final String embedUrl;
  final String originalUrl;
  final String cardKey;
  final String? caption;

  const _EmbedVideoCard({
    required this.embedUrl,
    required this.originalUrl,
    required this.cardKey,
    this.caption,
  });

  @override
  State<_EmbedVideoCard> createState() => _EmbedVideoCardState();
}

class _EmbedVideoCardState extends State<_EmbedVideoCard> {
  WebViewController? _controller;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  String _platformLabel(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('facebook') || host == 'fb.watch') {
      return 'Facebook';
    }
    if (host.contains('instagram')) return 'Instagram';
    if (host.contains('tiktok')) return 'TikTok';
    if (host.contains('drive.google')) return 'Google Drive';
    return 'le site d\'origine';
  }

  Future<void> _openOriginalUrl() async {
    final uri = Uri.tryParse(widget.originalUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _load() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage ??=
                    'Le contenu n\u2019a pas pu être chargé.';
              });
            }
          },
          onNavigationRequest: (request) {
            if (request.url == widget.embedUrl ||
                request.url.startsWith('about:')) {
              return NavigationDecision.navigate;
            }
            final requestUri = Uri.tryParse(request.url);
            if (requestUri != null) {
              launchUrl(requestUri,
                  mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    controller.loadRequest(Uri.parse(widget.embedUrl));
    setState(() => _controller = controller);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_controller == null) return;
    if (info.visibleFraction > 0.05) return;

    if (mounted) {
      setState(() {
        _controller = null;
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentGreen.withValues(alpha: 0.25),
            AppTheme.surfaceColor,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasError
                  ? Icons.play_disabled
                  : Icons.play_circle_fill,
              size: 56,
              color: _hasError
                  ? Colors.white70
                  : AppTheme.accentGreen,
            ),
            const SizedBox(height: 10),
            Text(
              _hasError
                  ? 'Lecture impossible ici'
                  : 'Appuyez pour lire',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (_hasError) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _openOriginalUrl,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                    'Ouvrir sur ${_platformLabel(widget.originalUrl)}'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.cardKey),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: (_controller == null && !_hasError) ? _load : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null && !_hasError)
                  WebViewWidget(controller: _controller!),
                if (_controller == null || _hasError)
                  _buildPlaceholderBackground(),
                if (_isLoading && !_hasError)
                  const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accentGreen),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}