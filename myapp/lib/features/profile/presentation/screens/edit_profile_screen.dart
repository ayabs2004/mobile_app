import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/snackbar_utils.dart' show SnackBarUtils;
import '../../../../core/utils/media_upload_service.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender;
  String? _preferredLanguage;
  bool _marketingOptIn = false;
  String? _avatarUrl;
  bool _saving = false;
  bool _loadedOnce = false;

  static const _genders = ['homme', 'femme', 'autre'];
  static const _languages = ['fr', 'en', 'ar'];

  void _prefillFrom(Map<String, dynamic>? profile) {
    if (_loadedOnce || profile == null) return;
    _loadedOnce = true;
    _fullNameController.text = profile['full_name'] as String? ?? '';
    _phoneController.text = profile['phone'] as String? ?? '';
    _avatarUrl = profile['avatar_url'] as String?;
    _gender = profile['gender'] as String?;
    _preferredLanguage = profile['preferred_language'] as String?;
    _marketingOptIn = profile['marketing_opt_in'] as bool? ?? false;
    final dob = profile['date_of_birth'] as String?;
    if (dob != null) _dateOfBirth = DateTime.tryParse(dob);
  }

  Future<void> _pickAvatar() async {
    final image = await MediaUploadService.pickImageFromGallery();
    if (image == null) return;

    final currentUserId =
        ref.read(myProfileProvider).valueOrNull?['id'] as String? ?? '';
    final result = await MediaUploadService.uploadImage(
      image: image,
      entityType: 'profile',
      entityId: currentUserId,
    );
    setState(() => _avatarUrl = result.url);
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            avatarUrl: _avatarUrl,
            dateOfBirth: _dateOfBirth,
            gender: _gender,
            preferredLanguage: _preferredLanguage,
            marketingOptIn: _marketingOptIn,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Profil mis à jour');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.friendlyMessage(e, context: 'la mise à jour du profil'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    _prefillFrom(profileAsync.valueOrNull);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Compléter mon profil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur de chargement : $e',
              style: const TextStyle(color: Colors.white)),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.surfaceColor,
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.add_a_photo_outlined,
                          color: AppTheme.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _fullNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            const SizedBox(height: 14),
            ListTile(
              tileColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text(
                _dateOfBirth == null
                    ? 'Date de naissance'
                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                style: const TextStyle(color: Colors.white),
              ),
              trailing:
                  const Icon(Icons.calendar_today, color: AppTheme.accentGreen),
              onTap: _pickDateOfBirth,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              dropdownColor: AppTheme.surfaceColor,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Genre'),
              items: _genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              dropdownColor: AppTheme.surfaceColor,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Langue préférée'),
              items: _languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _preferredLanguage = v),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              tileColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              activeThumbColor: AppTheme.accentGreen,
              title: const Text('Recevoir les communications marketing',
                  style: TextStyle(color: Colors.white)),
              value: _marketingOptIn,
              onChanged: (v) => setState(() => _marketingOptIn = v),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}