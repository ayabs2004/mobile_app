import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';

/// Écran affiché tant que l'utilisateur n'a pas confirmé son adresse email.
///
/// Deux cas possibles :
/// - Juste après l'inscription : Supabase n'ouvre pas de session tant que
///   l'email n'est pas confirmé (aucun `currentUser`). On affiche alors un
///   message statique + bouton de renvoi, avec l'email transmis via
///   `extra` depuis l'écran d'inscription.
/// - Un utilisateur déjà connecté dont l'email n'est pas confirmé (cas rare,
///   dépend de la configuration Supabase) : on peut alors vérifier
///   périodiquement si la session s'est confirmée.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  Timer? _autoCheckTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  bool get _hasActiveSession => SupabaseConfig.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    // Ne vérifie automatiquement que s'il existe une session active
    // (sinon il n'y a rien à rafraîchir tant que le lien n'est pas cliqué).
    if (_hasActiveSession) {
      _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkVerification(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final verified = await ref
          .read(authControllerProvider.notifier)
          .refreshEmailVerificationStatus();
      if (verified && mounted) {
        _autoCheckTimer?.cancel();
        context.go('/home');
        return;
      }
      if (!silent && !verified && mounted) {
        SnackBarUtils.showError(
          context,
          'Email pas encore confirmé. Vérifiez votre boîte de réception.',
        );
      }
    } catch (_) {
      // Silencieux : on retentera au prochain tick / clic manuel.
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    final email = SupabaseConfig.client.auth.currentUser?.email ?? widget.email;
    if (email == null || _resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).resendConfirmationEmail(email);
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Email de confirmation renvoyé à $email');
      }
      setState(() => _resendCooldown = 30);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) t.cancel();
        });
      });
    } on AuthException catch (e) {
      if (mounted) SnackBarUtils.showError(context, e.message);
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Erreur lors du renvoi de l\'email.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseConfig.client.auth.currentUser?.email ?? widget.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppTheme.logoGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [AppTheme.greenGlow],
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Vérifiez votre email',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nous avons envoyé un lien de confirmation à\n$email\n\n'
                  'Ouvrez cet email et cliquez sur le lien pour activer votre compte.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_hasActiveSession)
                  ElevatedButton(
                    onPressed: _isChecking ? null : () => _checkVerification(),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text("J'ai confirmé mon email"),
                  )
                else
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Aller à la connexion'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_isResending || _resendCooldown > 0) ? null : _resendEmail,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Renvoyer l\'email (${_resendCooldown}s)'
                        : 'Renvoyer l\'email de confirmation',
                    style: const TextStyle(color: AppTheme.accentGreen),
                  ),
                ),
                if (_hasActiveSession) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text(
                      'Se déconnecter',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}