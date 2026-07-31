import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../players/data/models/player_model.dart';
import '../../../sports/data/models/competition_model.dart';
import '../providers/admin_players_provider.dart';
import '../providers/admin_content_providers.dart';
import '../../../players/presentation/providers/public_players_provider.dart';

/// Formulaire joueur, utilisé pour DEUX contextes :
///  - isAmateur = false : joueur PRO, rattaché à un sport PUIS une
///    compétition (dropdown en cascade : le sport filtre les compétitions).
///  - isAmateur = true : joueur AMATEUR, rattaché uniquement à un sport.
///    Pas de compétition.
class AdminPlayerFormScreen extends ConsumerStatefulWidget {
  final CompetitionModel? competition; // pré-sélection optionnelle (pro)
  final bool isAmateur;
  final PlayerModel? existingPlayer; // null = création, sinon = modification

  const AdminPlayerFormScreen({
    super.key,
    this.competition,
    required this.isAmateur,
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
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _bioController;
  bool _isSaving = false;

  // Utilisé pour amateur ET pro.
  String? _selectedSportId;
  // Utilisé uniquement pour pro (filtré par _selectedSportId).
  String? _selectedCompetitionId;

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

    // Sport : priorité au joueur existant, sinon à la compétition
    // pré-remplie (widget.competition), sinon rien.
    _selectedSportId = p?.sportId ?? widget.competition?.sportId;
    _selectedCompetitionId = p?.competitionId ?? widget.competition?.id;
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
    super.dispose();
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSportId == null) {
      SnackBarUtils.showError(context, 'Veuillez choisir un sport');
      return;
    }
    if (!widget.isAmateur && _selectedCompetitionId == null) {
      SnackBarUtils.showError(context, 'Veuillez choisir une compétition');
      return;
    }

    setState(() => _isSaving = true);

    final player = PlayerModel(
      id: widget.existingPlayer?.id ?? '',
      competitionId: widget.isAmateur ? null : _selectedCompetitionId,
      sportId: _selectedSportId,
      type: widget.isAmateur ? 'amateur' : 'pro',
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
    );

    try {
      final repo = ref.read(adminPlayersRepositoryProvider);
      if (_isEditing) {
        await repo.updatePlayer(widget.existingPlayer!.id, player);
      } else {
        await repo.createPlayer(player);
      }

      if (widget.isAmateur) {
        ref.invalidate(adminAmateurPlayersProvider);
        if (_selectedSportId != null) {
          ref.invalidate(
              publicAmateurPlayersBySportProvider(_selectedSportId!));
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

  /// Dropdown Sport, partagé par les deux contextes (amateur / pro).
  /// Pour le pro, changer de sport réinitialise la compétition choisie.
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
              if (!widget.isAmateur) {
                // Le sport a changé : la compétition précédente ne
                // correspond plus forcément à ce sport.
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

  /// Dropdown Compétition (pro uniquement), filtré par sport sélectionné
  /// via le provider family adminCompetitionsBySportProvider(sportId).
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
            // Sécurité : si la compétition mémorisée n'appartient plus
            // à la liste filtrée (ex: après changement de sport), on
            // ne la propose pas comme valeur initiale.
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
    final title = _isEditing
        ? 'Modifier le joueur'
        : widget.isAmateur
            ? 'Nouveau joueur amateur'
            : 'Nouveau joueur pro';

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
              if (!widget.isAmateur) ...[
                const SizedBox(height: 14),
                _buildCompetitionDropdown(),
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
              TextFormField(
                controller: _imageUrlController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'URL photo de profil'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _coverImageUrlController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'URL photo de couverture'),
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