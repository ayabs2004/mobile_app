import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'has_seen_onboarding';

// Provider synchrone, initialisé avec une valeur connue dès le démarrage
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

class OnboardingController {
  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}

final onboardingControllerProvider = Provider((ref) => OnboardingController());

// Fonction utilitaire appelée une seule fois dans main(), avant runApp()
Future<bool> loadOnboardingStatus() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingKey) ?? false;
}