import 'package:supabase_flutter/supabase_flutter.dart';

import 'license_model.dart';

class LicenseRepository {
  final SupabaseClient _client;

  LicenseRepository(this._client);

  /// La licence est stockee dans une seule ligne, id = 1.
  Future<LicenseModel?> getLicense() async {
    final data = await _client
        .from('license')
        .select()
        .eq('id', 1)
        .maybeSingle();

    if (data == null) return null;

    return LicenseModel.fromMap(data);
  }
}
