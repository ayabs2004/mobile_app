import 'license_model.dart';
import 'license_repository.dart';

class LicenseService {
  final LicenseRepository _repository;

  LicenseService(this._repository);

  Future<LicenseModel?> checkLicense() async {
    try {
      return await _repository.getLicense();
    } catch (e) {
      // En cas de coupure reseau/erreur, on considere la licence comme invalide
      // (fail-closed) plutot que de laisser passer silencieusement.
      return null;
    }
  }

  Future<bool> isLicenseValid() async {
    final license = await checkLicense();

    if (license == null) return false;

    return license.isValid;
  }
}
