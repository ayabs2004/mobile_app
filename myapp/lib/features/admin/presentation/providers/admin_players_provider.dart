import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../players/data/models/player_model.dart';
import '../../data/repositories/admin_players_repository.dart';

final adminPlayersRepositoryProvider =
    Provider((ref) => AdminPlayersRepository());

/// Filtre commun aux listes de joueurs (pro et amateur) : sport optionnel
/// + texte de recherche courant (vide = pas de filtre).
class AdminPlayersFilter {
  final String? sportId;
  final String? competitionId;
  final String search;
  const AdminPlayersFilter({this.sportId, this.competitionId, this.search = ''});

  @override
  bool operator ==(Object other) =>
      other is AdminPlayersFilter &&
      other.sportId == sportId &&
      other.competitionId == competitionId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(sportId, competitionId, search);
}

/// Liste des joueurs PRO, filtrée par sport (via compétition) + recherche.
final adminAllProPlayersProvider =
    FutureProvider.family<List<PlayerModel>, AdminPlayersFilter>((ref, f) {
  return ref
      .read(adminPlayersRepositoryProvider)
      .getPlayersBySport(f.sportId, competitionId: f.competitionId, search: f.search);
});

/// Liste des joueurs AMATEURS, filtrée par sport + recherche.
final adminAmateurPlayersProvider =
    FutureProvider.family<List<PlayerModel>, AdminPlayersFilter>((ref, f) {
  return ref
      .read(adminPlayersRepositoryProvider)
      .getAmateurPlayers(search: f.search, sportId: f.sportId);
});

/// Liste des joueurs ACADÉMIE, filtrée par sport + recherche.
final adminAcademiePlayersProvider =
    FutureProvider.family<List<PlayerModel>, AdminPlayersFilter>((ref, f) {
  return ref
      .read(adminPlayersRepositoryProvider)
      .getAcademiePlayers(search: f.search, sportId: f.sportId);
});

final adminCompetitionsOptionsProvider =
    FutureProvider<List<CompetitionOption>>((ref) async {
  return ref.read(adminPlayersRepositoryProvider).getAllCompetitions();
});

// adminAcademiesOptionsProvider -> SUPPRIMÉ (table academies supprimée)
// adminCoachesOptionsProvider -> SUPPRIMÉ (plus de FK player.coach_id,
// le formulaire joueur ne référence plus les coachs)