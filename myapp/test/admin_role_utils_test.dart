import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/admin/core/admin_role_utils.dart';

void main() {
  group('AdminRoleUtils Tests', () {
    test('roleDisplayLabel retourne les bons libellés', () {
      expect(roleDisplayLabel('super_admin'), equals('Super Admin'));
      expect(roleDisplayLabel('admin'), equals('Sous-admin'));
      expect(roleDisplayLabel('customer'), equals('Client'));
      expect(roleDisplayLabel('inconnu'), equals('inconnu'));
    });

    test('isAdminAreaRole identifie correctement les rôles autorisés', () {
      expect(isAdminAreaRole('super_admin'), isTrue);
      expect(isAdminAreaRole('admin'), isTrue);
      expect(isAdminAreaRole('customer'), isFalse);
      expect(isAdminAreaRole(null), isFalse);
    });

    test('isSuperAdminRole vérifie strictement le statut super_admin', () {
      expect(isSuperAdminRole('super_admin'), isTrue);
      expect(isSuperAdminRole('admin'), isFalse);
      expect(isSuperAdminRole('customer'), isFalse);
      expect(isSuperAdminRole(null), isFalse);
    });

    test('isSubAdminRole vérifie le statut admin secondaire', () {
      expect(isSubAdminRole('admin'), isTrue);
      expect(isSubAdminRole('super_admin'), isFalse);
      expect(isSubAdminRole('customer'), isFalse);
      expect(isSubAdminRole(null), isFalse);
    });
  });
}
