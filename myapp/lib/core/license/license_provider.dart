import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'license_model.dart';
import 'license_repository.dart';
import 'license_service.dart';

final licenseRepositoryProvider = Provider<LicenseRepository>((ref) {
  return LicenseRepository(Supabase.instance.client);
});

final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService(ref.watch(licenseRepositoryProvider));
});

final licenseProvider = FutureProvider<LicenseModel?>((ref) async {
  final service = ref.watch(licenseServiceProvider);
  return service.checkLicense();
});

final licenseValidProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(licenseServiceProvider);
  return service.isLicenseValid();
});
