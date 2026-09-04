import '../../../../core/config/supabase_config.dart';

/// Repository pour lire et mettre à jour la ligne `profiles` de
/// l'utilisateur actuellement connecté (les champs "facultatifs" que
/// handle_new_user() ne remplit pas à l'inscription : avatar_url,
/// date_of_birth, gender, preferred_language, marketing_opt_in).
class ProfileRepository {
  /// Récupère le profil complet de l'utilisateur connecté.
  /// Retourne `null` si aucun profil n'existe encore (ex: email pas
  /// encore confirmé -> handle_new_user() n'a pas encore créé la ligne).
  Future<Map<String, dynamic>?> getMyProfile() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return null;

    return await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Met à jour uniquement les champs fournis (les autres restent
  /// inchangés). Passe `null` explicitement si tu veux effacer un champ.
  Future<void> updateMyProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    String? gender,
    String? preferredLanguage,
    bool? marketingOptIn,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (dateOfBirth != null) {
      updates['date_of_birth'] =
          dateOfBirth.toIso8601String().split('T').first;
    }
    if (gender != null) updates['gender'] = gender;
    if (preferredLanguage != null) {
      updates['preferred_language'] = preferredLanguage;
    }
    if (marketingOptIn != null) updates['marketing_opt_in'] = marketingOptIn;

    if (updates.isEmpty) return;

    await SupabaseConfig.client.from('profiles').update(updates).eq('id', userId);
  }
}