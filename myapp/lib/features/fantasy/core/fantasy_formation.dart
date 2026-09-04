/// Regroupe une position brute ('GK', 'DEF', 'MIL', 'ATT', ...) dans l'une
/// des 4 lignes de formation, du gardien (proche du but) à l'attaque.
enum FormationLine { keeper, defense, midfield, attack }

FormationLine formationLineFor(String? rawPosition) {
  final p = (rawPosition ?? '').toUpperCase();
  if (p.startsWith('GK') || p.startsWith('GARD')) return FormationLine.keeper;
  if (p.startsWith('DEF')) return FormationLine.defense;
  if (p.startsWith('MIL') || p.startsWith('MID')) return FormationLine.midfield;
  return FormationLine.attack;
}

/// Un "poste" précis dans une formation (ex: 2e défenseur central).
class FormationSlot {
  final String id;
  final FormationLine line;

  const FormationSlot(this.id, this.line);
}

/// Un schéma tactique fixe (ex: 4-4-2) : nombre de joueurs par ligne.
/// Le gardien (1) est toujours implicite.
class FormationTemplate {
  final String key;
  final String label;
  final int defenders;
  final int midfielders;
  final int attackers;

  const FormationTemplate({
    required this.key,
    required this.label,
    required this.defenders,
    required this.midfielders,
    required this.attackers,
  });

  /// Nombre total de joueurs (gardien inclus) pour ce schéma.
  int get totalPlayers => 1 + defenders + midfielders + attackers;

  List<FormationSlot> get slots => [
        const FormationSlot('GK_0', FormationLine.keeper),
        for (var i = 0; i < defenders; i++)
          FormationSlot('DEF_$i', FormationLine.defense),
        for (var i = 0; i < midfielders; i++)
          FormationSlot('MIL_$i', FormationLine.midfield),
        for (var i = 0; i < attackers; i++)
          FormationSlot('ATT_$i', FormationLine.attack),
      ];
}

/// Clé spéciale : l'utilisateur ne choisit pas de schéma fixe et compose
/// son équipe librement (comportement historique de l'écran).
const String kFreeFormationKey = 'libre';

const List<FormationTemplate> kFormationTemplates = [
  FormationTemplate(key: '3-4-3', label: '3-4-3', defenders: 3, midfielders: 4, attackers: 3),
  FormationTemplate(key: '3-5-2', label: '3-5-2', defenders: 3, midfielders: 5, attackers: 2),
  FormationTemplate(key: '4-3-3', label: '4-3-3', defenders: 4, midfielders: 3, attackers: 3),
  FormationTemplate(key: '4-4-2', label: '4-4-2', defenders: 4, midfielders: 4, attackers: 2),
  FormationTemplate(key: '4-5-1', label: '4-5-1', defenders: 4, midfielders: 5, attackers: 1),
  FormationTemplate(key: '5-2-3', label: '5-2-3', defenders: 5, midfielders: 2, attackers: 3),
  FormationTemplate(key: '5-3-2', label: '5-3-2', defenders: 5, midfielders: 3, attackers: 2),
  FormationTemplate(key: '5-4-1', label: '5-4-1', defenders: 5, midfielders: 4, attackers: 1),
];

List<FormationTemplate> availableFormationsFor(int maxPlayers) {
  if (maxPlayers >= 11) {
    return kFormationTemplates;
  }
  return [];
}