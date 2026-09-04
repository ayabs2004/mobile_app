import '../../sports/data/models/sport_model.dart';

/// Le module fantasy n'existe que pour le foot et le hand.
/// Centralisé ici pour être utilisé aussi bien côté public (Home) que
/// côté admin (création de round).
bool isFantasySport(SportModel sport) {
  final key = '${sport.slug} ${sport.name}'.toLowerCase();
  return key.contains('foot') || key.contains('hand');
}
