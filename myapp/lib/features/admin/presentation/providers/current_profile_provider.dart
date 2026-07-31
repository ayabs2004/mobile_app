import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../core/admin_role_utils.dart';

final currentUserRoleProvider = FutureProvider<String>((ref) async {
  ref.watch(authStateProvider);

  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return 'customer';

  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

    return response['role'] as String? ?? 'customer';
  } catch (e) {
    // ignore: avoid_print
    print('Erreur lecture rôle utilisateur: $e');
    return 'customer';
  }
});

final canAccessAdminProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(currentUserRoleProvider);
  // N'affiche l'icône admin qu'une fois le rôle confirmé en base.
  if (roleAsync.isLoading || roleAsync.hasError) return false;
  return isAdminAreaRole(roleAsync.valueOrNull);
});

final isSuperAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return isSuperAdminRole(role);
});

final isSubAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return isSubAdminRole(role);
});