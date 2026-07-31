import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../data/repositories/admin_users_repository.dart';
import '../providers/admin_content_providers.dart';

class AdminEditSubAdminScreen extends ConsumerStatefulWidget {
  final UserProfileModel subAdmin;

  const AdminEditSubAdminScreen({super.key, required this.subAdmin});

  @override
  ConsumerState<AdminEditSubAdminScreen> createState() =>
      _AdminEditSubAdminScreenState();
}

class _AdminEditSubAdminScreenState extends ConsumerState<AdminEditSubAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.subAdmin.fullName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(adminUsersRepositoryProvider).updateSubAdmin(
            userId: widget.subAdmin.id,
            fullName: _nameController.text.trim(),
          );

      ref.invalidate(adminSubAdminsListProvider);
      ref.invalidate(adminUsersListProvider);

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Sous-admin modifié.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Supprimer ce sous-admin ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Le compte de ${widget.subAdmin.fullName ?? 'ce sous-admin'} '
          'sera définitivement supprimé.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);

    try {
      await ref
          .read(adminUsersRepositoryProvider)
          .deleteSubAdmin(widget.subAdmin.id);

      ref.invalidate(adminSubAdminsListProvider);
      ref.invalidate(adminUsersListProvider);
      ref.invalidate(adminAuditLogProvider);

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Sous-admin supprimé.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isDeleting;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Modifier le sous-admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('NOM COMPLET'),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isBusy ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Enregistrer'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: isBusy ? null : _handleDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Text('Supprimer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}
