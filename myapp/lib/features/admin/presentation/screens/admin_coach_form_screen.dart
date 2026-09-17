import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/media_upload_service.dart';
import '../../../../core/utils/video_url_resolver.dart';
import '../../../coaches/data/models/coach_model.dart';
import '../providers/admin_content_providers.dart';
import '../../../coaches/presentation/providers/coachs_provider.dart';
import '../../../players/data/models/player_model.dart';

class AdminCoachFormScreen extends ConsumerStatefulWidget {
  final CoachModel? existingCoach;
  const AdminCoachFormScreen({super.key, this.existingCoach});

  @override
  ConsumerState<AdminCoachFormScreen> createState() => _AdminCoachFormScreenState();
}

class _AdminCoachFormScreenState extends ConsumerState<AdminCoachFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _coverController;
  late final List<TextEditingController> _photoControllers;
  late final List<TextEditingController> _photoCaptionControllers;
  late final List<TextEditingController> _videoControllers;
  late final List<TextEditingController> _videoCaptionControllers;
  late final TextEditingController _bioController;
  late final TextEditingController _experienceController;
  late final TextEditingController _certificationsController;
  String? _selectedSportId;
  bool _isSaving = false;
  List<PlayerMediaItem> _mediaItems = [];

  List<CoachTeamExperience> _teamHistory = [];

  final Set<int> _uploadingVideoIndexes = {};

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

  bool get _isEditing => widget.existingCoach != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCoach;
    _nameController = TextEditingController(text: c?.fullName ?? '');
    _coverController = TextEditingController(text: c?.coverUrl ?? '');
    _photoControllers = [TextEditingController(text: c?.photoUrl ?? '')];
    _photoCaptionControllers = [TextEditingController()];
    _photoIds = [null];
    _videoControllers = [TextEditingController()];
    _videoCaptionControllers = [TextEditingController()];
    _videoThumbnails = [null];
    _videoIds = [null];
    _bioController = TextEditingController(text: c?.biography ?? '');
    _experienceController =
        TextEditingController(text: c?.yearsExperience?.toString() ?? '');
    _certificationsController =
        TextEditingController(text: c?.certifications.join(', ') ?? '');
    _selectedSportId = c?.sportId;
    _teamHistory = List.of(c?.teamHistory ?? []);

    if (c != null) {
      _loadExistingMedia(c.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
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
    _bioController.dispose();
    _experienceController.dispose();
    _certificationsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingMedia(String coachId) async {
    try {
      final repo = ref.read(adminCoachesRepositoryProvider);
      final media = await repo.getCoachMedia(coachId);
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
          _photoControllers.add(TextEditingController(text: _coverController.text));
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
      final storageEntityId = widget.existingCoach?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadImage(
        image: image,
        entityType: 'coach',
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
      final storageEntityId = widget.existingCoach?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadImage(
        image: image,
        entityType: 'coach',
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
      final storageEntityId = widget.existingCoach?.id ??
          'pending-${DateTime.now().millisecondsSinceEpoch}';

      final result = await MediaUploadService.uploadVideo(
        video: video,
        entityType: 'coach',
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

    final storageEntityId = widget.existingCoach?.id ??
        'pending-${DateTime.now().millisecondsSinceEpoch}';

    final thumbUrl = await MediaUploadService.generateThumbnailForUrl(
      videoUrl: url,
      entityType: 'coach',
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

  String _slugify(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');

  Future<void> _showTeamEntryDialog({
    CoachTeamExperience? existing,
    int? index,
  }) async {
    final teamController = TextEditingController(text: existing?.teamName ?? '');
    final startController =
        TextEditingController(text: existing?.startYear.toString() ?? '');
    final endController =
        TextEditingController(text: existing?.endYear?.toString() ?? '');
    bool isCurrent = existing?.isCurrent ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            existing == null ? 'Ajouter une équipe' : 'Modifier l\'équipe',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: teamController,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Nom de l\'équipe'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Année de début'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Équipe actuelle',
                      style: TextStyle(color: Colors.white)),
                  value: isCurrent,
                  activeThumbColor: AppTheme.accentGreen,
                  onChanged: (v) => setDialogState(() => isCurrent = v),
                ),
                if (!isCurrent)
                  TextField(
                    controller: endController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Année de fin'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                final startYear = int.tryParse(startController.text.trim());
                if (teamController.text.trim().isEmpty || startYear == null) {
                  return;
                }

                final entry = CoachTeamExperience(
                  teamName: teamController.text.trim(),
                  startYear: startYear,
                  endYear:
                      isCurrent ? null : int.tryParse(endController.text.trim()),
                );

                setState(() {
                  if (index != null) {
                    _teamHistory[index] = entry;
                  } else {
                    _teamHistory.add(entry);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Sauvegarde en une seule transaction (coach + médias) : un seul log
  /// d'audit consolidé est généré côté base ("création" ou "modification"
  /// avec le détail champ par champ, médias compris) — jamais de log
  /// "média" séparé. Les ids des médias existants sont reportés depuis
  /// `_photoIds` / `_videoIds` pour que le diff SQL ne journalise que ce qui
  /// a réellement changé (voir admin_apply_media_diff côté base).
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSportId == null) {
      SnackBarUtils.showError(context, 'Sélectionnez un sport');
      return;
    }
    setState(() => _isSaving = true);

    String? firstPhotoUrl;
    for (final controller in _photoControllers) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        firstPhotoUrl = value;
        break;
      }
    }

    final coach = CoachModel(
      id: widget.existingCoach?.id ?? '',
      sportId: _selectedSportId!,
      fullName: _nameController.text.trim(),
      slug: _slugify(_nameController.text.trim()),
      photoUrl: firstPhotoUrl,
      coverUrl: _coverController.text.trim().isEmpty
          ? null
          : _coverController.text.trim(),
      biography:
          _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      yearsExperience: int.tryParse(_experienceController.text.trim()),
      certifications: _certificationsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      teamHistory: _teamHistory,
    );

    final mediaItems = <PlayerMediaItem>[];
    for (int i = 0; i < _photoControllers.length; i++) {
      final value = _photoControllers[i].text.trim();
      if (value.isEmpty) continue;
      final caption = _photoCaptionControllers[i].text.trim();
      mediaItems.add(PlayerMediaItem(
        id: _photoIds[i],
        entityType: 'coach',
        entityId: widget.existingCoach?.id ?? '',
        mediaType: 'image',
        url: value,
        caption: caption.isEmpty ? null : caption,
        isCover: i == 0,
        displayOrder: i,
      ));
    }
    for (int i = 0; i < _videoControllers.length; i++) {
      final value = _videoControllers[i].text.trim();
      if (value.isEmpty) continue;
      if (_videoThumbnails[i] == null && _isDirectVideoLink(value)) {
        await _generateThumbnailForPastedUrl(i);
      }
      final caption = _videoCaptionControllers[i].text.trim();
      mediaItems.add(PlayerMediaItem(
        id: _videoIds[i],
        entityType: 'coach',
        entityId: widget.existingCoach?.id ?? '',
        mediaType: 'video',
        url: value,
        caption: caption.isEmpty ? null : caption,
        thumbnailUrl: _videoThumbnails[i],
        displayOrder: 1000 + i,
      ));
    }

    try {
      final repo = ref.read(adminCoachesRepositoryProvider);
      if (_isEditing) {
        await repo.updateCoachWithMedia(widget.existingCoach!.id, coach, mediaItems);
      } else {
        await repo.createCoachWithMedia(coach, mediaItems);
      }

      if (_selectedSportId != null) {
        ref.invalidate(adminCoachesListProvider(_selectedSportId!));
        ref.invalidate(publicCoachesBySportProvider(_selectedSportId!));
      }
      ref.invalidate(adminCoachesListProvider);
      ref.invalidate(publicCoachesListProvider);
      if (_isEditing) {
        ref.invalidate(publicCoachDetailProvider(widget.existingCoach!.id));
      }
      if (mounted) {
        SnackBarUtils.showSuccess(
            context, _isEditing ? 'Coach mis à jour' : 'Coach créé');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportsAsync = ref.watch(adminSportsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar:
          AppBar(title: Text(_isEditing ? 'Modifier coach' : 'Nouveau coach')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              sportsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => const Text('Erreur',
                    style: TextStyle(color: Colors.redAccent)),
                data: (sports) => DropdownButtonFormField<String>(
                  initialValue: _selectedSportId,
                  dropdownColor: AppTheme.surfaceColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: sports
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSportId = v),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _photoControllers.first,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'URL photo de profil',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choisir depuis le téléphone',
                    onPressed: _uploadingPhotoIndexes.contains(0)
                        ? null
                        : () => _showImageSourceSheet(
                              onGalleryTap: () => _pickImageFromDevice(0, fromCamera: false),
                              onCameraTap: () => _pickImageFromDevice(0, fromCamera: true),
                            ),
                    icon: _uploadingPhotoIndexes.contains(0)
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
                      controller: _coverController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'URL photo de couverture',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choisir depuis le téléphone',
                    onPressed: _isUploadingCoverImage
                        ? null
                        : () => _showImageSourceSheet(
                              onGalleryTap: () => _pickSingleImageFromDevice(
                                _coverController,
                                fromCamera: false,
                                setUploadingState: (val) => _isUploadingCoverImage = val,
                              ),
                              onCameraTap: () => _pickSingleImageFromDevice(
                                _coverController,
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
              TextFormField(
                controller: _experienceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Années d'expérience"),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _certificationsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Certifications (séparées par virgule)'),
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
                              decoration: InputDecoration(labelText: 'URL photo ${index + 1}'),
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
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Biographie'),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historique des équipes',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppTheme.accentGreen),
                    tooltip: 'Ajouter une équipe',
                    onPressed: () => _showTeamEntryDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_teamHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucune équipe ajoutée.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                ..._teamHistory.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (team.isCurrent)
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Actuel',
                              style: TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.teamName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                team.isCurrent
                                    ? 'Depuis ${team.startYear} · ${team.durationYears} an(s)'
                                    : '${team.startYear} – ${team.endYear} · ${team.durationYears} an(s)',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppTheme.textSecondary),
                          onPressed: () => _showTeamEntryDialog(
                              existing: team, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () =>
                              setState(() => _teamHistory.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Enregistrer' : 'Créer le coach'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}