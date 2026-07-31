import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return SupabaseConfig.client.auth.currentUser;
});

/// True si l'utilisateur connecté a confirmé son adresse email.
/// Si personne n'est connecté, considéré comme non pertinent (true) pour
/// ne pas bloquer les écrans publics.
final isEmailVerifiedProvider = Provider<bool>((ref) {
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) return true;
  return user.emailConfirmedAt != null;
});

/// True si l'utilisateur connecté vient d'un compte invité (admin créé via
/// inviteUserByEmail) et n'a pas encore choisi son propre mot de passe.
/// Ce flag est posé côté serveur (user_metadata.must_set_password) lors de
/// l'invitation, et retiré une fois le mot de passe défini.
final mustSetPasswordProvider = Provider<bool>((ref) {
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) return false;
  return user.userMetadata?['must_set_password'] == true;
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncValue.data(null));

  /// Retourne `true` si une session a été ouverte immédiatement (email déjà
  /// considéré confirmé côté Supabase), `false` si une confirmation par
  /// email est requise avant de pouvoir se connecter.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final metadata = {'full_name': fullName};
      if (phone != null && phone.isNotEmpty) {
        metadata['phone'] = phone;
      }

      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      state = const AsyncValue.data(null);
      return response.session != null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseConfig.client.auth.signInWithOAuth(provider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  /// Renvoie l'email de confirmation d'inscription.
  Future<void> resendConfirmationEmail(String email) async {
    await SupabaseConfig.client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Recharge la session courante pour vérifier si l'email vient d'être
  /// confirmé (ex: après avoir cliqué sur le lien reçu par email).
  Future<bool> refreshEmailVerificationStatus() async {
    final res = await SupabaseConfig.client.auth.refreshSession();
    return res.user?.emailConfirmedAt != null;
  }

  Future<void> resetPasswordForEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.myapp://reset-callback',
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Définit le mot de passe d'un compte fraîchement invité (admin créé via
  /// inviteUserByEmail) et retire le flag `must_set_password` de ses
  /// métadonnées pour ne plus être redirigé vers cet écran ensuite.
  Future<void> setInitialPassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      final currentMetadata =
          SupabaseConfig.client.auth.currentUser?.userMetadata ?? {};
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(
          password: newPassword,
          data: {...currentMetadata, 'must_set_password': false},
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController();
});