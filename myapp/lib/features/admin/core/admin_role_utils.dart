/// Libellés d'affichage pour les rôles utilisateur.
String roleDisplayLabel(String role) {
  switch (role) {
    case 'super_admin':
      return 'Super Admin';
    case 'admin':
      return 'Sous-admin';
    case 'customer':
      return 'Client';
    default:
      return role;
  }
}

bool isAdminAreaRole(String? role) =>
    role == 'admin' || role == 'super_admin';

bool isSuperAdminRole(String? role) => role == 'super_admin';

bool isSubAdminRole(String? role) => role == 'admin';
