import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Le profil complet (avatar, date de naissance, genre, langue,
/// consentement marketing...) de l'utilisateur connecté.
/// `null` tant que l'email n'est pas confirmé (voir handle_new_user()),
/// ou si personne n'est connecté.
///
/// Important : ce provider dépend explicitement de `currentUserProvider`
/// (via ref.watch) pour se re-déclencher automatiquement à chaque
/// changement d'utilisateur (login/logout/switch de compte). Sans ça,
/// Riverpod garde le résultat en cache tant que le provider n'est pas
/// recréé, et affiche donc le profil de l'ancien utilisateur.
final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);

  return ref.watch(profileRepositoryProvider).getMyProfile();
});