import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/set_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../config/supabase_config.dart';
import '../../features/sports/data/models/sport_model.dart';
import '../../features/sports/data/models/competition_model.dart';
import '../../features/admin/presentation/screens/admin_sports_list_screen.dart';
import '../../features/admin/presentation/screens/admin_competitions_list_screen.dart';
import '../../features/admin/presentation/screens/admin_players_list_screen.dart';
import '../../features/admin/presentation/screens/admin_amateur_players_list_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_player_form_screen.dart';
import '../../features/admin/presentation/providers/current_profile_provider.dart';
import '../../features/players/data/models/player_model.dart';
import '../../features/players/presentation/screens/public_players_list_screen.dart';
import '../../features/players/presentation/screens/public_player_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_coaches_list_screen.dart';
import '../../features/admin/presentation/screens/admin_coach_form_screen.dart';
import '../../features/admin/presentation/screens/admin_users_list_screen.dart';
import '../../features/admin/presentation/screens/admin_sub_admins_list_screen.dart';
import '../../features/admin/presentation/screens/admin_create_sub_admin_screen.dart';
import '../../features/admin/presentation/screens/admin_edit_sub_admin_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_log_screen.dart';
import '../../features/admin/data/repositories/admin_users_repository.dart';
import '../../features/admin/core/admin_role_utils.dart';
import '../../features/coaches/data/models/coach_model.dart';
import '../../features/auth/presentation/screens/account_screen.dart';
import '../../features/coaches/presentation/screens/public_coaches_list_screen.dart';
import '../../features/coaches/presentation/screens/public_coach_detail_screen.dart';
import '../../features/players/presentation/screens/public_amateurs_list_screen.dart';
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      notifyListeners();
    });
  }

  bool _isPasswordRecovery = false;
  bool get isPasswordRecovery => _isPasswordRecovery;

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier();
});

final routerProvider = Provider<GoRouter>((ref) {
  final hasSeenOnboarding = ref.watch(onboardingCompletedProvider);
  final authNotifier = ref.watch(authChangeNotifierProvider);
  final userRoleAsync = ref.watch(currentUserRoleProvider);

  ref.listen(currentUserRoleProvider, (_, __) => authNotifier.notifyListeners());

  return GoRouter(
    initialLocation: hasSeenOnboarding ? '/login' : '/onboarding',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = SupabaseConfig.client.auth.currentSession != null;
      final role = userRoleAsync.valueOrNull;
      final roleLoading = userRoleAsync.isLoading;
      final canAccessAdmin = isAdminAreaRole(role);
      final isSuperAdmin = isSuperAdminRole(role);
      final isEmailVerified =
          SupabaseConfig.client.auth.currentUser?.emailConfirmedAt != null;
      final mustSetPassword =
          SupabaseConfig.client.auth.currentUser?.userMetadata?[
                  'must_set_password'] ==
              true;

      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isResetRoute = state.matchedLocation == '/reset-password';
      final isVerifyEmailRoute = state.matchedLocation == '/verify-email';
      final isSetPasswordRoute = state.matchedLocation == '/set-password';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isAdminRoute = state.matchedLocation.startsWith('/admin');

      if (authNotifier.isPasswordRecovery && !isResetRoute) {
        return '/reset-password';
      }

      if (!hasSeenOnboarding && !isOnboardingRoute) return '/onboarding';
      if (hasSeenOnboarding && isOnboardingRoute) return '/login';

      if (!isLoggedIn &&
          !isAuthRoute &&
          !isOnboardingRoute &&
          !isResetRoute &&
          !isVerifyEmailRoute) {
        return '/login';
      }

      if (isLoggedIn && mustSetPassword && !isSetPasswordRoute) {
        return '/set-password';
      }
      if (isLoggedIn && !mustSetPassword && isSetPasswordRoute) {
        return '/home';
      }

      if (isLoggedIn && !isEmailVerified && !isVerifyEmailRoute && !isResetRoute) {
        return '/verify-email';
      }
      if (isLoggedIn && isEmailVerified && isVerifyEmailRoute) {
        return '/home';
      }

      if (isLoggedIn && isAuthRoute) return '/home';

      if (isAdminRoute) {
        if (roleLoading) return null;
        if (!canAccessAdmin) return '/home';
      }

      final isSuperAdminRoute =
          state.matchedLocation.startsWith('/admin/sub-admins') ||
              state.matchedLocation.startsWith('/admin/audit-log') ||
              state.matchedLocation == '/admin/users/create-admin';
      if (isSuperAdminRoute) {
        if (roleLoading) return null;
        if (!isSuperAdmin) return '/admin';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (c, s) => const ResetPasswordScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (c, s) => VerifyEmailScreen(email: s.extra as String?),
      ),
      GoRoute(path: '/set-password', builder: (c, s) => const SetPasswordScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),

      GoRoute(
        path: '/sport/:slug/competition/:id/players',
        builder: (c, s) {
          final id = s.pathParameters['id']!;
          final extra = s.extra as Map<String, dynamic>?;
          return PublicPlayersListScreen(
            competitionId: id,
            sportName: extra?['sportName'] as String?,
            competitionName: extra?['competitionName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/sport/:slug/coachs',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return PublicCoachesListScreen(
            sportId: extra?['sportId'] as String? ?? '',
            sportName: extra?['sportName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/coach/:id',
        builder: (c, s) => PublicCoachDetailScreen(coachId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:id',
        builder: (c, s) => PublicPlayerDetailScreen(playerId: s.pathParameters['id']!),
      ),

      // ---- Admin dashboard ----
      GoRoute(path: '/admin', builder: (c, s) => const AdminDashboardScreen()),

      // ---- Sports & Compétitions (s'arrête au niveau compétition) ----
      GoRoute(path: '/admin/sports', builder: (c, s) => const AdminSportsListScreen()),
      GoRoute(
        path: '/admin/sports/:sportId/competitions',
        builder: (c, s) => AdminCompetitionsListScreen(sport: s.extra as SportModel),
      ),

      // ---- Joueurs PRO (vue globale, sidebar, filtre par sport) ----
      GoRoute(path: '/admin/players', builder: (c, s) => const AdminPlayersListScreen()),
      GoRoute(
        path: '/admin/players/new',
        builder: (c, s) => const AdminPlayerFormScreen(isAmateur: false),
      ),
      GoRoute(
        path: '/admin/players/edit/:id',
        builder: (c, s) => AdminPlayerFormScreen(
          isAmateur: false,
          existingPlayer: s.extra as PlayerModel,
        ),
      ),
      GoRoute(
  path: '/sport/:slug/amateurs',
  builder: (c, s) {
    final extra = s.extra as Map<String, dynamic>?;
    return PublicAmateursListScreen(
      sportId: extra?['sportId'] as String? ?? '',
      sportName: extra?['sportName'] as String?,
    );
  },
),
      // ---- Amateurs (filtre par sport) ----
      GoRoute(
        path: '/admin/amateurs',
        builder: (c, s) => const AdminAmateurPlayersListScreen(),
      ),
      GoRoute(
        path: '/admin/amateurs/new',
        builder: (c, s) => const AdminPlayerFormScreen(isAmateur: true),
      ),
      GoRoute(
        path: '/admin/amateurs/edit/:id',
        builder: (c, s) => AdminPlayerFormScreen(
          isAmateur: true,
          existingPlayer: s.extra as PlayerModel,
        ),
      ),

      // ---- Coachs (filtre par sport) ----
      GoRoute(path: '/admin/coaches', builder: (c, s) => const AdminCoachesListScreen()),
      GoRoute(path: '/admin/coaches/new', builder: (c, s) => const AdminCoachFormScreen()),
      GoRoute(
        path: '/admin/coaches/edit/:id',
        builder: (c, s) => AdminCoachFormScreen(existingCoach: s.extra as CoachModel),
      ),

      // ---- Utilisateurs / sous-admins ----
      GoRoute(path: '/admin/users', builder: (c, s) => const AdminUsersListScreen()),
      GoRoute(
        path: '/admin/users/create-admin',
        builder: (c, s) => const AdminCreateSubAdminScreen(),
      ),
      GoRoute(
        path: '/admin/sub-admins',
        builder: (c, s) => const AdminSubAdminsListScreen(),
      ),
      GoRoute(
        path: '/admin/sub-admins/create',
        builder: (c, s) => const AdminCreateSubAdminScreen(),
      ),
      GoRoute(
        path: '/admin/sub-admins/edit/:id',
        builder: (c, s) => AdminEditSubAdminScreen(subAdmin: s.extra as UserProfileModel),
      ),
      GoRoute(path: '/admin/audit-log', builder: (c, s) => const AdminAuditLogScreen()),
    ],
  );
});