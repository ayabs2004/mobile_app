import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, String initialName, String initialPhone) async {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: initialPhone);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Modifier mon profil', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom', labelStyle: TextStyle(color: Colors.white54))),
            TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Téléphone', labelStyle: TextStyle(color: Colors.white54))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(authControllerProvider.notifier).updateProfile(fullName: nameCtrl.text, phone: phoneCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                SnackbarUtils.showSuccess(context, 'Profil mis à jour');
              } catch (e) {
                SnackbarUtils.showError(context, 'Erreur');
              }
            },
            child: const Text('Enregistrer', style: TextStyle(color: AppTheme.accentGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final fullName = user?.userMetadata?['full_name'] as String? ?? '-';
    final phone = user?.userMetadata?['phone'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Mon compte'), actions: [ IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _showEditDialog(context, ref, fullName, phone ?? ''),) ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: AppTheme.logoGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(icon: Icons.person_outline, label: 'Nom complet', value: fullName),
          _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? '-'),
          if (phone != null && phone.isNotEmpty)
            _InfoTile(icon: Icons.phone_outlined, label: 'Téléphone', value: phone),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, String initialName, String initialPhone) async {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: initialPhone);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Modifier mon profil', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom', labelStyle: TextStyle(color: Colors.white54))),
            TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Téléphone', labelStyle: TextStyle(color: Colors.white54))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(authControllerProvider.notifier).updateProfile(fullName: nameCtrl.text, phone: phoneCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                SnackbarUtils.showSuccess(context, 'Profil mis à jour');
              } catch (e) {
                SnackbarUtils.showError(context, 'Erreur');
              }
            },
            child: const Text('Enregistrer', style: TextStyle(color: AppTheme.accentGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
