import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/coach_model.dart';
import '../../data/repositories/coach_repository.dart';

final publicCoachesRepositoryProvider = Provider<PublicCoachesRepository>((ref) {
  return PublicCoachesRepository();
});

final publicCoachesListProvider = FutureProvider<List<CoachModel>>((ref) {
  return ref.read(publicCoachesRepositoryProvider).getAllCoaches();
});

final publicCoachesBySportProvider =
    FutureProvider.family<List<CoachModel>, String>((ref, sportId) {
  return ref.read(publicCoachesRepositoryProvider).getCoachesBySport(sportId);
});

final publicCoachDetailProvider =
    FutureProvider.family<CoachModel, String>((ref, coachId) {
  return ref.read(publicCoachesRepositoryProvider).getCoachById(coachId);
});