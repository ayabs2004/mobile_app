import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';

class AuthRepository {
  Future<void> ensureSession() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) {
      await SupabaseConfig.client.auth.signInAnonymously();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
