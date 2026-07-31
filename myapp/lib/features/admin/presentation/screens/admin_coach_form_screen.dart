import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../coaches/data/models/coach_model.dart';
import '../providers/admin_content_providers.dart';
import '../../../coaches/presentation/providers/coachs_provider.dart';

class AdminCoachFormScreen extends ConsumerStatefulWidget {
  final CoachModel? existingCoach;
  const AdminCoachFormScreen({super.key, this.existingCoach});

  @override
  ConsumerState<AdminCoachFormScreen> createState() => _AdminCoachFormScreenState();
}

class _AdminCoachFormScreenState extends ConsumerState<AdminCoachFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;
  late final TextEditingController _bioController;
  late final TextEditingController _experienceController;
  late final TextEditingController _certificationsController;
  String? _selectedSportId;
  bool _isSaving = false;

  List<CoachTeamExperience> _teamHistory = [];

  bool get _isEditing => widget.existingCoach != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCoach;
    _nameController = TextEditingController(text: c?.fullName ?? '');
    _photoController = TextEditingController(text: c?.photoUrl ?? '');
    _bioController = TextEditingController(text: c?.biography ?? '');
    _experienceController =
        TextEditingController(text: c?.yearsExperience?.toString() ?? '');
    _certificationsController =
        TextEditingController(text: c?.certifications.join(', ') ?? '');
    _selectedSportId = c?.sportId;
    _teamHistory = List.of(c?.teamHistory ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _certificationsController.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSportId == null) {
      SnackBarUtils.showError(context, 'Sélectionnez un sport');
      return;
    }
    setState(() => _isSaving = true);

    final coach = CoachModel(
      id: widget.existingCoach?.id ?? '',
      sportId: _selectedSportId!,
      fullName: _nameController.text.trim(),
      slug: _slugify(_nameController.text.trim()),
      photoUrl:
          _photoController.text.trim().isEmpty ? null : _photoController.text.trim(),
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

    try {
      final repo = ref.read(adminCoachesRepositoryProvider);
      if (_isEditing) {
        await repo.updateCoach(widget.existingCoach!.id, coach);
      } else {
        await repo.createCoach(coach);
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
              TextFormField(
                controller: _photoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'URL photo'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Biographie'),
              ),

              // ---------- Historique des équipes ----------
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