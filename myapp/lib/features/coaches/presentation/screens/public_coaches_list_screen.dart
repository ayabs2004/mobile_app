import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../data/models/coach_model.dart';
import '../providers/coachs_provider.dart';

class PublicCoachesListScreen extends ConsumerWidget {
  final String sportId;
  final String? sportName;

  const PublicCoachesListScreen({
    super.key,
    required this.sportId,
    this.sportName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(publicCoachesBySportProvider(sportId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(sportName != null ? 'Coachs — $sportName' : 'Coachs'),
      ),
      body: coachesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (err, st) => Center(
          child: Text(
            ErrorUtils.friendlyMessage(err),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (coaches) {
          if (coaches.isEmpty) {
            return const Center(
              child: Text(
                'Aucun coach pour le moment.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: coaches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final CoachModel coach = coaches[index];
              return Material(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/coach/${coach.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: coach.photoUrl != null
                              ? NetworkImage(coach.photoUrl!)
                              : null,
                          child: coach.photoUrl == null
                              ? const Icon(Icons.sports, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(coach.fullName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              if (coach.yearsExperience != null)
                                Text(
                                  '${coach.yearsExperience} ans d\'expérience',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12.5),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}