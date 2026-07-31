import '../../../../core/config/supabase_config.dart';

class UserProfileModel {
  final String id;
  final String? fullName;
  final String role;

  UserProfileModel({required this.id, this.fullName, required this.role});

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String? ?? 'customer',
      );
}

class AdminUsersRepository {
  Future<List<UserProfileModel>> getAllUsers() async {
    final res = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, role')
        .order('full_name');
    return (res as List).map((j) => UserProfileModel.fromJson(j)).toList();
  }

  Future<List<UserProfileModel>> getSubAdmins() async {
    final res = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, role')
        .eq('role', 'admin')
        .order('full_name');
    return (res as List).map((j) => UserProfileModel.fromJson(j)).toList();
  }

  /// Change le rôle d'un utilisateur existant.
  ///
  /// Ne fait plus d'update direct sur `profiles` (bloqué côté base par le
  /// trigger `prevent_role_change` une fois la migration SQL appliquée) :
  /// passe par la même fonction Edge sécurisée que `createAdmin`.
  Future<void> setRole(String userId, String role) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'admin-create-user',
      body: {
        'action': 'set_role',
        'userId': userId,
        'role': role,
      },
    );

    final data = response.data;
    if (response.status != 200) {
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Erreur lors du changement de rôle.';
      throw Exception(message);
    }
  }

  /// Crée un sous-admin (super admin uniquement, vérifié côté Edge Function).
  Future<void> createSubAdmin({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    await _invokeAdminFunction({
      'action': 'create_sub_admin',
      'email': email,
      'password': password,
      'fullName': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    }, fallbackError: 'Erreur lors de la création du sous-admin.');
  }

  /// @deprecated Utiliser [createSubAdmin]. Conservé pour compatibilité.
  Future<void> createAdmin({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) =>
      createSubAdmin(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

  Future<void> updateSubAdmin({
    required String userId,
    required String fullName,
  }) async {
    await _invokeAdminFunction({
      'action': 'update_sub_admin',
      'userId': userId,
      'fullName': fullName,
    }, fallbackError: 'Erreur lors de la modification du sous-admin.');
  }

  Future<void> deleteSubAdmin(String userId) async {
    await _invokeAdminFunction({
      'action': 'delete_sub_admin',
      'userId': userId,
    }, fallbackError: 'Erreur lors de la suppression du sous-admin.');
  }

  Future<void> _invokeAdminFunction(
    Map<String, dynamic> body, {
    required String fallbackError,
  }) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'admin-create-user',
      body: body,
    );

    final data = response.data;
    if (response.status != 200) {
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : fallbackError;
      throw Exception(message);
    }
  }
}