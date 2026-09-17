import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/media_upload_service.dart';
import '../../../../core/utils/video_url_resolver.dart';
import '../../../players/data/models/player_model.dart';
import '../../../players/data/models/player_with_stats_model.dart';
import '../../../sports/data/models/competition_model.dart';
import '../providers/admin_players_provider.dart';
import '../providers/admin_content_providers.dart';
import '../../../players/presentation/providers/public_players_provider.dart';
import '../../../fantasy/presentation/providers/admin_fantasy_provider.dart';
import '../../../fantasy/presentation/providers/fantasy_provider.dart';
import '../../../../core/config/supabase_config.dart';

/// Formulaire joueur, utilisé pour TROIS contextes :
///  - playerType = 'pro' : joueur PRO, rattaché à un sport PUIS une
///    compétition (dropdown en cascade : le sport filtre les compétitions).
///  - playerType = 'amateur' : joueur AMATEUR, rattaché uniquement à un sport.
///    Pas de compétition.
///  - playerType = 'academie' : joueur ACADÉMIE, rattaché à un sport et avec un niveau.
class AdminPlayerFormScreen extends ConsumerStatefulWidget {
  final String? prefillSportId;
  final String? prefillCompetitionId;
  final String playerType; // 'pro' | 'amateur' | 'academie'
  final PlayerModel? existingPlayer; // null = création, sinon = modification

  const AdminPlayerFormScreen({
    super.key,
    this.prefillSportId,
    this.prefillCompetitionId,
    required this.playerType,
    this.existingPlayer,
  });

  @override
  ConsumerState<AdminPlayerFormScreen> createState() =>
      _AdminPlayerFormScreenState();
}

class _AdminPlayerFormScreenState extends ConsumerState<AdminPlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _teamNameController;
  late final TextEditingController _positionController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _jerseyController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _coverImageUrlController;
  late final List<TextEditingController> _photoControllers;
  late final List<TextEditingController> _photoCaptionControllers;
  late final List<TextEditingController> _videoControllers;
  late final List<TextEditingController> _videoCaptionControllers;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _bioController;
  late final TextEditingController _matchesController;
  late final TextEditingController _goalsController;
  late final TextEditingController _assistsController;
  late final TextEditingController _yellowCardsController;
  late final TextEditingController _redCardsController;
  late final TextEditingController _minutesPlayedController;
  late final TextEditingController _fantasyPriceController;
  bool _isSaving = false;

  // Pricing fantasy existant avant modif (utile si l'admin vide le champ :
  // on désactive le joueur pour le fantasy plutôt que de perdre le coût,
  // car fantasy_player_pricing.cost a CHECK (cost > 0) et ne peut pas
  // être remis à NULL/0).
  double? _existingFantasyCost;

  final Set<int> _uploadingVideoIndexes = {};

  bool _isUploadingProfileImage = false;
  bool _isUploadingCoverImage = false;
  final Set<int> _uploadingPhotoIndexes = {};

  late final List<String?> _videoThumbnails;
  final Set<int> _generatingThumbnailIndexes = {};

  // Ids des médias existants en base, alignés index par index avec les
  // controllers correspondants. `null` = média pas encore en base (nouveau).
  // Indispensable pour que le diff SQL (admin_apply_media_diff) ne journalise
  // que le média réellement ajouté/modifié/supprimé, et pas tous les médias.
  late final List<String?> _photoIds;
  late final List<String?> _videoIds;

  String? _selectedSportId;
  String? _selectedCompetitionId;
  String? _selectedNiveau;
  List<PlayerMediaItem> _mediaItems = [];
  bool get _isEditing => widget.existingPlayer != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlayer;
    _nameController = TextEditingController(text: p?.fullName ?? '');
    _teamNameController = TextEditingController(text: p?.teamName ?? '');
    _positionController = TextEditingController(text: p?.position ?? '');
    _nationalityController = TextEditingController(text: p?.nationality ?? '');
    _jerseyController =
        TextEditingController(text: p?.jerseyNumber?.toString() ?? '');
    _imageUrlController =
        TextEditingController(text: p?.profileImageUrl ?? '');
    _coverImageUrlController =
        TextEditingController(text: p?.coverImageUrl ?? '');
    _heightController = TextEditingController(text: p?.heightCm?.toString() ?? '');
    _weightController = TextEditingController(text: p?.weightKg?.toString() ?? '');
    _bioController = TextEditingController(text: p?.biography ?? '');
    _matchesController = TextEditingController(text: '0');
    _goalsController = TextEditingController(text: '0');
    _assistsController = TextEditingController(text: '0');
    _yellowCardsController = TextEditingController(text: '0');
    _redCardsController = TextEditingController(text: '0');
    _minutesPlayedController = TextEditingController(text: '0');
    _fantasyPriceController = TextEditingController();
    _photoControllers = [TextEditingController()];
    _photoCaptionControllers = [TextEditingController()];
    _photoIds = [null];
    _videoControllers = [TextEditingController()];
    _videoCaptionControllers = [TextEditingController()];
    _videoThumbnails = [null];
    _videoIds = [null];

    _selectedSportId = p?.sportId ?? widget.prefillSportId;
    _selectedCompetitionId = p?.competitionId ?? widget.prefillCompetitionId;
    _selectedNiveau = p?.niveau;

    if (p != null) {
      _fetchPlayerStats(p.id);
      _loadExistingMedia(p.id);
      _loadFantasyPricing(p.id);
    }
  }

  Future<void> _loadFantasyPricing(String playerId) async {
    try {
      final pricing = await ref
          .read(adminFantasyRepositoryProvider)
          .getPricingForPlayer(playerId);
      if (!mounted || pricing == null) return;
      setState(() {
        _existingFantasyCost = pricing.cost;
        // On ne préremplit le champ que si le joueur est actuellement
        // disponible en fantasy ; s'il a été désactivé, on laisse le
        // champ vide (l'admin verra un placeholder neutre plutôt qu'un
        // prix qui suggère à tort que le joueur est sélectionnable).
        if (pricing.isAvailable) {
          _fantasyPriceController.text = pricing.cost.toStringAsFixed(1);
        }
      });
    } catch (_) {
      // Pas bloquant : si la lecture du pricing échoue, le formulaire
      // reste utilisable, l'admin pourra simplement resaisir le prix.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamNameController.dispose();
    _positionController.dispose();
    _nationalityController.dispose();
    _jerseyController.dispose();
    _imageUrlController.dispose();
    _coverImageUrlController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bioController.dispose();
    _matchesController.dispose();
    _goalsController.dispose();
    _assistsController.dispose();
    _yellowCardsController.dispose();
    _redCardsController.dispose();
    _minutesPlayedController.dispose();
    _fantasyPriceController.dispose();
    for (final controller in _photoControllers) {
      controller.dispose();
    }
    for (final controller in _photoCaptionControllers) {
      controller.dispose();
    }
    for (final controller in _videoControllers) {
      controller.dispose();
    }
    for (final controller in _videoCaptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingMedia(String playerId) async {
    try {
      final repo = ref.read(adminPlayersRepositoryProvider);
      final media = await repo.getPlayerMedia(playerId);
      if (!mounted) return;
      setState(() {
        _mediaItems = media;
        _photoControllers.clear();
        _photoCaptionControllers.clear();
        _photoIds.clear();
        _videoControllers.clear();
        _videoCaptionControllers.clear();
        _videoThumbnails.clear();
        _videoIds.clear();

        for (final item in media.where((m) => m.mediaType == 'image')) {
          _photoControllers.add(TextEditingController(text: item.url));
          _photoCaptionControllers
              .add(TextEditingController(text: item.caption ?? ''));
          _photoIds.add(item.id);
        }
        if (_photoControllers.isEmpty) {
          _photoControllers.add(TextEditingController());
          _photoCaptionControllers.add(TextEditingController());
          _photoIds.add(null);
        }

        for (final item in media.where((m) => m.mediaType == 'video')) {
          _videoControllers.add(TextEditingController(text: item.url));
          _videoCaptionControllers
              .add(TextEditingController(text: item.caption ?? ''));
          _videoThumbnails.add(item.thumbnailUrl);
          _videoIds.add(item.id);
        }
        if (_videoControllers.isEmpty) {
          _videoControllers.add(TextEditingController());
          _videoCaptionControllers.add(TextEditingController());
          _videoThumbnails.add(null);
          _videoIds.add(null);
        }
      });
    } catch (_) {}
  }

  /// Score recalculé en direct à chaque frappe, avec la même formule
  /// que celle utilisée côté public (PlayerStatisticsModel.score).
  double _computeLiveScore() {
    return PlayerStatisticsModel(
      matchesPlayed: int.tryParse(_matchesController.text.trim()) ?? 0,
      goals: int.tryParse(_goalsController.text.trim()) ?? 0,
      assists: int.tryParse(_assistsController.text.trim()) ?? 0,
      yellowCards: int.tryParse(_yellowCardsController.text.trim()) ?? 0,
      redCards: int.tryParse(_redCardsController.text.trim()) ?? 0,
      minutesPlayed: int.tryParse(_minutesPlayedController.text.trim()) ?? 0,
    ).score;
  }

  Future<void> _fetchPlayerStats(String playerId) async {
    try {
      final res = await SupabaseConfig.client
          .from('player_statistics')
          .select()
          .eq('player_id', playerId)
          .order('season', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _matchesController.text = (res['matches_played'] ?? 0).toString();
          _goalsController.text = (res['goals'] ?? 0).toString();
          _assistsController.text = (res['assists'] ?? 0).toString();
          _yellowCardsController.text = (res['yellow_cards'] ?? 0).toString();
          _redCardsController.text = (res['red_cards'] ?? 0).toString();
          _minutesPlayedController.text =
              (res['minutes_played'] ?? 0).toString();
        });
      }
    } catch (_) {}
  }

  void _addPhotoField() {
    setState(() {
      _photoControllers.add(TextEditingController());
      _photoCaptionControllers.add(TextEditingController());
      _photoIds.add(null);
    });
  }

  void _addVideoField() {
    setState(() {
      _videoControllers.add(TextEditingController());
      _videoCaptionControllers.add(TextEditingController());
      _videoThumbnails.add(null);
      _videoIds.add(null);
    });
  }

  void _removePhotoField(int index) {
    if (_photoControllers.length <= 1) return;
    setState(() {
      _photoControllers[index].dispose();
      _photoControllers.removeAt(index);
      _photoCaptionControllers[index].dispose();
      _photoCaptionControllers.removeAt(index);
      _photoIds.removeAt(index);
    });
  }

  void _removeVideoField(int index) {
    if (_videoControllers.length <= 1) return;
    setState(() {
      _videoControllers[index].dispose();
      _videoControllers.removeAt(index);
      _videoCaptionControllers[index].dispose();
      _videoCaptionControllers.removeAt(index);
      _videoThumbnails.removeAt(index);
      _videoIds.removeAt(index);
    });
  }

  void _showImageSourceSheet({
    required VoidCallback onGalleryTap,
    required VoidCallback onCameraTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                'Photo depuis le téléphone',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accentGreen),
              title: const Text('Choisir depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onGalleryTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.accentGreen),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onCameraTap();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromDevice(int index, {required bool fromCamera}) async {
    final image = fromCamera
        ? await MediaUploadService.takePhoto()
        : await MediaUploadService.pickImageFromGallery();

    if (image == null || !mounted) return;

    setState(() => _uploadingPhotoIndexes.add(index));

    try {
      final storageEntityId = widget.existingPlayer?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadImage(
        image: image,
        entityType: 'player',
        entityId: storageEntityId,
      );

      if (!mounted) return;
      setState(() {
        _photoControllers[index].text = result.url;
      });
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
            context, 'Échec de l\'upload : ${ErrorUtils.friendlyMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhotoIndexes.remove(index));
    }
  }

  Future<void> _pickSingleImageFromDevice(
    TextEditingController controller, {
    required bool fromCamera,
    required Function(bool) setUploadingState,
  }) async {
    final image = fromCamera
        ? await MediaUploadService.takePhoto()
        : await MediaUploadService.pickImageFromGallery();

    if (image == null || !mounted) return;

    setState(() => setUploadingState(true));

    try {
      final storageEntityId = widget.existingPlayer?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadImage(
        image: image,
        entityType: 'player',
        entityId: storageEntityId,
      );

      if (!mounted) return;
      setState(() {
        controller.text = result.url;
      });
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
            context, 'Échec de l\'upload : ${ErrorUtils.friendlyMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => setUploadingState(false));
    }
  }

  Future<void> _pickVideoFromDevice(int index, {required bool fromCamera}) async {
    final video = fromCamera
        ? await MediaUploadService.recordVideo()
        : await MediaUploadService.pickVideoFromGallery();

    if (video == null || !mounted) return;

    setState(() => _uploadingVideoIndexes.add(index));

    try {
      final storageEntityId = widget.existingPlayer?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadVideo(
        video: video,
        entityType: 'player',
        entityId: storageEntityId,
      );

      if (!mounted) return;
      setState(() {
        _videoControllers[index].text = result.url;
        _videoThumbnails[index] = result.thumbnailUrl;
      });
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
            context, 'Échec de l\'upload : ${ErrorUtils.friendlyMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploadingVideoIndexes.remove(index));
    }
  }

  bool _isDirectVideoLink(String url) {
    if (url.trim().isEmpty) return false;
    if (VideoUrlResolver.extractYoutubeVideoId(url) != null) return false;
    final source = VideoUrlResolver.resolve(url);
    return !source.isEmbed;
  }

  Future<void> _generateThumbnailForPastedUrl(int index) async {
    if (index >= _videoControllers.length) return;
    final url = _videoControllers[index].text.trim();
    if (!_isDirectVideoLink(url)) return;
    if (_videoThumbnails[index] != null) return;

    setState(() => _generatingThumbnailIndexes.add(index));

    final storageEntityId = widget.existingPlayer?.id ??
        'pending-${DateTime.now().millisecondsSinceEpoch}';

    final thumbUrl = await MediaUploadService.generateThumbnailForUrl(
      videoUrl: url,
      entityType: 'player',
      entityId: storageEntityId,
    );

    if (!mounted) return;
    setState(() {
      _generatingThumbnailIndexes.remove(index);
      if (thumbUrl != null) _videoThumbnails[index] = thumbUrl;
    });
  }

  void _showVideoSourceSheet(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                'Vidéo depuis le téléphone',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined, color: AppTheme.accentGreen),
              title: const Text('Choisir depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromDevice(index, fromCamera: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Sauvegarde en une seule transaction (joueur + médias) : un seul log
  /// d'audit consolidé côté base ("création" ou "modification" avec le
  /// détail champ par champ, médias compris) — jamais de log "média" séparé.
  /// Les ids des médias existants sont reportés depuis `_photoIds` /
  /// `_videoIds` pour que le diff SQL ne journalise que ce qui a réellement
  /// changé (voir admin_apply_media_diff côté base).
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSportId == null) {
      SnackBarUtils.showError(context, 'Veuillez choisir un sport');
      return;
    }
    if (widget.playerType == 'pro' && _selectedCompetitionId == null) {
      SnackBarUtils.showError(context, 'Veuillez choisir une compétition');
      return;
    }
    if (widget.playerType == 'academie' && _selectedNiveau == null) {
      SnackBarUtils.showError(context, 'Veuillez choisir un niveau');
      return;
    }

    setState(() => _isSaving = true);

    final player = PlayerModel(
      id: widget.existingPlayer?.id ?? '',
      competitionId: widget.playerType == 'pro' ? _selectedCompetitionId : null,
      sportId: _selectedSportId,
      type: widget.playerType,
      teamName: _teamNameController.text.trim().isEmpty
          ? null
          : _teamNameController.text.trim(),
      fullName: _nameController.text.trim(),
      slug: _slugify(_nameController.text.trim()),
      position: _positionController.text.trim().isEmpty
          ? null
          : _positionController.text.trim(),
      nationality: _nationalityController.text.trim().isEmpty
          ? null
          : _nationalityController.text.trim(),
      jerseyNumber: int.tryParse(_jerseyController.text.trim()),
      profileImageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      coverImageUrl: _coverImageUrlController.text.trim().isEmpty
          ? null
          : _coverImageUrlController.text.trim(),
      heightCm: int.tryParse(_heightController.text.trim()),
      weightKg: int.tryParse(_weightController.text.trim()),
      biography:
          _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      niveau: widget.playerType == 'academie' ? _selectedNiveau : null,
    );

    final mediaItems = <PlayerMediaItem>[];
    for (int i = 0; i < _photoControllers.length; i++) {
      final url = _photoControllers[i].text.trim();
      if (url.isEmpty) continue;
      final caption = _photoCaptionControllers[i].text.trim();
      mediaItems.add(PlayerMediaItem(
        id: _photoIds[i],
        entityType: 'player',
        entityId: widget.existingPlayer?.id ?? '',
        mediaType: 'image',
        url: url,
        caption: caption.isEmpty ? null : caption,
        isCover: i == 0,
        displayOrder: i,
      ));
    }
    for (int i = 0; i < _videoControllers.length; i++) {
      final url = _videoControllers[i].text.trim();
      if (url.isEmpty) continue;
      if (_videoThumbnails[i] == null && _isDirectVideoLink(url)) {
        await _generateThumbnailForPastedUrl(i);
      }
      final caption = _videoCaptionControllers[i].text.trim();
      mediaItems.add(PlayerMediaItem(
        id: _videoIds[i],
        entityType: 'player',
        entityId: widget.existingPlayer?.id ?? '',
        mediaType: 'video',
        url: url,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: _videoThumbnails[i],
        displayOrder: 1000 + i,
      ));
    }

    try {
      final repo = ref.read(adminPlayersRepositoryProvider);
      String playerId;
      if (_isEditing) {
        playerId = widget.existingPlayer!.id;
        await repo.updatePlayerWithMedia(playerId, player, mediaItems);
      } else {
        final created = await repo.createPlayerWithMedia(player, mediaItems);
        playerId = created.id;
      }

      final matches = int.tryParse(_matchesController.text.trim()) ?? 0;
      final goals = int.tryParse(_goalsController.text.trim()) ?? 0;
      final assists = int.tryParse(_assistsController.text.trim()) ?? 0;
      final yellowCards =
          int.tryParse(_yellowCardsController.text.trim()) ?? 0;
      final redCards = int.tryParse(_redCardsController.text.trim()) ?? 0;
      final minutesPlayed =
          int.tryParse(_minutesPlayedController.text.trim()) ?? 0;
      await repo.savePlayerStats(
        playerId: playerId,
        matchesPlayed: matches,
        goals: goals,
        assists: assists,
        yellowCards: yellowCards,
        redCards: redCards,
        minutesPlayed: minutesPlayed,
      );

      // ---- Pricing fantasy ----
      // - champ rempli avec une valeur valide -> upsert prix + disponible.
      // - champ vidé alors qu'un prix existait -> on désactive le joueur
      //   pour le fantasy sans perdre son ancien coût (cost > 0 obligatoire
      //   en base), pour que le budget/l'historique restent cohérents si
      //   le joueur est réactivé plus tard.
      // - champ vidé et aucun prix n'a jamais existé -> rien à faire.
      final fantasyPriceText = _fantasyPriceController.text.trim();
      if (fantasyPriceText.isNotEmpty) {
        final parsedCost = double.parse(fantasyPriceText.replaceAll(',', '.'));
        await ref.read(adminFantasyRepositoryProvider).upsertPricing(
              playerId: playerId,
              cost: parsedCost,
              isAvailable: true,
            );
      } else if (_existingFantasyCost != null) {
        await ref.read(adminFantasyRepositoryProvider).upsertPricing(
              playerId: playerId,
              cost: _existingFantasyCost!,
              isAvailable: false,
            );
      }
      ref.invalidate(adminFantasyPricingProvider);
      ref.invalidate(fantasyPricedPlayersProvider);

      if (widget.playerType == 'amateur') {
        ref.invalidate(adminAmateurPlayersProvider);
        if (_selectedSportId != null) {
          ref.invalidate(
              publicAmateurPlayersBySportProvider(_selectedSportId!));
        }
      } else if (widget.playerType == 'academie') {
        ref.invalidate(adminAcademiePlayersProvider);
        if (_selectedSportId != null) {
          ref.invalidate(
              publicAcademiePlayersBySportProvider(_selectedSportId!));
        }
      } else {
        ref.invalidate(adminAllProPlayersProvider);
        if (_selectedCompetitionId != null) {
          ref.invalidate(
              publicPlayersByCompetitionProvider(_selectedCompetitionId!));
        }
      }

      if (_isEditing) {
        ref.invalidate(publicPlayerDetailProvider(widget.existingPlayer!.id));
      }

      if (mounted) {
        SnackBarUtils.showSuccess(
            context, _isEditing ? 'Joueur mis à jour' : 'Joueur créé');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSportDropdown() {
    return Consumer(
      builder: (context, ref, _) {
        final sportsAsync = ref.watch(adminSportsListProvider);
        return sportsAsync.when(
          data: (sports) => DropdownButtonFormField<String>(
            initialValue: _selectedSportId,
            dropdownColor: AppTheme.surfaceColor,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Sport *'),
            items: sports
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.iconEmoji ?? ""} ${s.name}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedSportId = v;
              if (widget.playerType == 'pro') {
                _selectedCompetitionId = null;
              }
            }),
            validator: (v) => v == null ? 'Sport requis' : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, __) => Text(ErrorUtils.friendlyMessage(e),
              style: const TextStyle(color: AppTheme.textSecondary)),
        );
      },
    );
  }

  Widget _buildCompetitionDropdown() {
    if (_selectedSportId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Choisissez un sport pour voir les compétitions disponibles',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final competitionsAsync = ref.watch(
          adminCompetitionsBySportProvider(_selectedSportId!),
        );
        return competitionsAsync.when(
          data: (competitions) {
            final validInitial =
                competitions.any((c) => c.id == _selectedCompetitionId)
                    ? _selectedCompetitionId
                    : null;

            if (competitions.isEmpty) {
              return const Text(
                'Aucune compétition pour ce sport',
                style: TextStyle(color: AppTheme.textSecondary),
              );
            }

            return DropdownButtonFormField<String>(
              initialValue: validInitial,
              dropdownColor: AppTheme.surfaceColor,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Compétition *'),
              items: competitions
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCompetitionId = v),
              validator: (v) => v == null ? 'Compétition requise' : null,
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, __) => Text(ErrorUtils.friendlyMessage(e),
              style: const TextStyle(color: AppTheme.textSecondary)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel = '';
    if (widget.playerType == 'amateur') {
      typeLabel = 'amateur';
    } else if (widget.playerType == 'academie') {
      typeLabel = 'académie';
    } else {
      typeLabel = 'pro';
    }

    final title = _isEditing
        ? 'Modifier le joueur'
        : 'Nouveau joueur $typeLabel';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSportDropdown(),
              if (widget.playerType == 'pro') ...[
                const SizedBox(height: 14),
                _buildCompetitionDropdown(),
              ],
              if (widget.playerType == 'academie') ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedNiveau,
                  dropdownColor: AppTheme.surfaceColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Niveau *'),
                  items: ['Minimes', 'Cadets', 'Juniors']
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedNiveau = v),
                  validator: (v) => v == null ? 'Niveau requis' : null,
                ),
              ],
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _teamNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Équipe / club (libre, ex: Espérance de Tunis)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _positionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Poste (ex: Attaquant)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _jerseyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Numéro de maillot'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nationalityController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nationalité'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _imageUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'URL photo de profil'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choisir depuis le téléphone',
                    onPressed: _isUploadingProfileImage
                        ? null
                        : () => _showImageSourceSheet(
                              onGalleryTap: () => _pickSingleImageFromDevice(
                                _imageUrlController,
                                fromCamera: false,
                                setUploadingState: (val) => _isUploadingProfileImage = val,
                              ),
                              onCameraTap: () => _pickSingleImageFromDevice(
                                _imageUrlController,
                                fromCamera: true,
                                setUploadingState: (val) => _isUploadingProfileImage = val,
                              ),
                            ),
                    icon: _isUploadingProfileImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accentGreen),
                          )
                        : const Icon(Icons.phone_iphone, color: AppTheme.accentGreen),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _coverImageUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'URL photo de couverture'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choisir depuis le téléphone',
                    onPressed: _isUploadingCoverImage
                        ? null
                        : () => _showImageSourceSheet(
                              onGalleryTap: () => _pickSingleImageFromDevice(
                                _coverImageUrlController,
                                fromCamera: false,
                                setUploadingState: (val) => _isUploadingCoverImage = val,
                              ),
                              onCameraTap: () => _pickSingleImageFromDevice(
                                _coverImageUrlController,
                                fromCamera: true,
                                setUploadingState: (val) => _isUploadingCoverImage = val,
                              ),
                            ),
                    icon: _isUploadingCoverImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accentGreen),
                          )
                        : const Icon(Icons.phone_iphone, color: AppTheme.accentGreen),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._photoControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                final isUploading = _uploadingPhotoIndexes.contains(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'URL photo ${index + 1}',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Choisir depuis le téléphone',
                            onPressed: isUploading
                                ? null
                                : () => _showImageSourceSheet(
                                      onGalleryTap: () => _pickImageFromDevice(index, fromCamera: false),
                                      onCameraTap: () => _pickImageFromDevice(index, fromCamera: true),
                                    ),
                            icon: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.accentGreen),
                                  )
                                : const Icon(Icons.phone_iphone, color: AppTheme.accentGreen),
                          ),
                          if (_photoControllers.length > 1)
                            IconButton(
                              onPressed: () => _removePhotoField(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _photoCaptionControllers[index],
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Titre de la photo (optionnel)',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              TextButton.icon(
                onPressed: _addPhotoField,
                icon: const Icon(Icons.add, color: AppTheme.accentGreen),
                label: const Text('Ajouter une autre photo', style: TextStyle(color: AppTheme.accentGreen)),
              ),
              const SizedBox(height: 14),
              const Text('Vidéos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Collez un lien (YouTube, Facebook...) ou choisissez un fichier depuis le téléphone. '
                'Une miniature est générée automatiquement pour les fichiers vidéo directs.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ..._videoControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                final isUploading = _uploadingVideoIndexes.contains(index);
                final isGeneratingThumb = _generatingThumbnailIndexes.contains(index);
                final hasThumbnail = _videoThumbnails[index] != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(labelText: 'URL vidéo ${index + 1}'),
                              onEditingComplete: () => _generateThumbnailForPastedUrl(index),
                              onTapOutside: (_) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                _generateThumbnailForPastedUrl(index);
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Choisir depuis le téléphone',
                            onPressed:
                                isUploading ? null : () => _showVideoSourceSheet(index),
                            icon: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.accentGreen),
                                  )
                                : const Icon(Icons.phone_iphone, color: AppTheme.accentGreen),
                          ),
                          if (_videoControllers.length > 1)
                            IconButton(
                              onPressed: () => _removeVideoField(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            ),
                        ],
                      ),
                      if (isGeneratingThumb)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Génération de la miniature…',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        )
                      else if (hasThumbnail)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Miniature prête ✓',
                              style: TextStyle(color: AppTheme.accentGreen, fontSize: 11)),
                        ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _videoCaptionControllers[index],
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Titre de la vidéo (optionnel)',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              TextButton.icon(
                onPressed: _addVideoField,
                icon: const Icon(Icons.add, color: AppTheme.accentGreen),
                label: const Text('Ajouter une autre vidéo', style: TextStyle(color: AppTheme.accentGreen)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Taille (cm)'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Poids (kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Biographie'),
              ),
              // Le fantasy ne concerne jamais les joueurs académie : le champ
              // n'a donc de sens que pour les joueurs pro et amateur.
              if (widget.playerType != 'academie') ...[
                const SizedBox(height: 20),
                const Text(
                  'Fantasy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Laisse vide si ce joueur ne doit pas être sélectionnable '
                  'dans le jeu fantasy.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fantasyPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Prix fantasy (ex: 8.5)',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final parsed = double.tryParse(text.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Entre un prix valide (supérieur à 0)';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Statistiques du joueur (Saison en cours)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Statistiques en grille 2 colonnes : avec 3 champs par ligne,
              // des libellés comme "Cartons jaunes" ou "Minutes jouées"
              // n'avaient pas assez de place et étaient coupés à l'affichage.
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _matchesController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Matchs'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _goalsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Buts'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _assistsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Passes'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minutesPlayedController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Minutes jouées'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yellowCardsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          const InputDecoration(labelText: 'Cartons jaunes'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _redCardsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          const InputDecoration(labelText: 'Cartons rouges'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        color: AppTheme.accentGreen, size: 20),
                    const SizedBox(width: 10),
                    const Text('Score calculé',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      _computeLiveScore().toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Enregistrer' : 'Créer le joueur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}