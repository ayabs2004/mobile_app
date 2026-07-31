class AuditLogEntry {
  final String id;
  final String? actorId;
  final String? actorName;
  final String action;
  final String entityType;
  final String? entityId;
  final String? entityLabel;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    this.actorId,
    this.actorName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityLabel,
    this.details,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AuditLogEntry(
      id: json['id'] as String,
      actorId: json['actor_id'] as String?,
      actorName: actor?['full_name'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      entityLabel: json['entity_label'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get actionLabel {
    switch (action) {
      case 'create':
        return 'a créé';
      case 'update':
        return 'a modifié';
      case 'delete':
        return 'a supprimé';
      default:
        return action;
    }
  }

  String get entityTypeLabel {
    switch (entityType) {
      case 'players':
        return 'le joueur';
      case 'teams':
        return 'l\'équipe';
      case 'coaches':
        return 'le coach';
      case 'academies':
        return 'l\'académie';
      case 'neighborhood_teams':
        return 'l\'équipe de quartier';
      case 'sub_admin':
        return 'le sous-admin';
      default:
        return entityType;
    }
  }

  /// Retourne les lignes de détails à afficher selon le type d'action.
  /// - create : nom de l'entité créée (depuis details ou entityLabel)
  /// - update : liste des champs modifiés avec ancienne et nouvelle valeur
  /// - delete : rien de plus (entityLabel suffit)
  List<AuditDetailLine> get detailLines {
    if (details == null || details!.isEmpty) return [];

    if (action == 'create') {
      // Le trigger stocke souvent le nouveau record dans details['new'] ou details['after']
      final newData = (details!['new'] ?? details!['after']) as Map<String, dynamic>?;
      final name = newData?['full_name'] as String?
          ?? newData?['name'] as String?
          ?? entityLabel;
      if (name != null && name != entityLabel) {
        return [AuditDetailLine(label: 'Nom', value: name, isNew: true)];
      }
      return [];
    }

    if (action == 'update') {
      final oldData = (details!['old'] ?? details!['before']) as Map<String, dynamic>? ?? {};
      final newData = (details!['new'] ?? details!['after']) as Map<String, dynamic>? ?? {};
      // Chercher aussi le format plat {changes: {field: {old:x, new:y}}}
      final flatChanges = details!['changes'] as Map<String, dynamic>?;

      final lines = <AuditDetailLine>[];

      if (flatChanges != null) {
        for (final e in flatChanges.entries) {
          final field = AuditDetailLine.friendlyFieldName(e.key);
          final change = e.value as Map<String, dynamic>?;
          if (change != null) {
            lines.add(AuditDetailLine(
              label: field,
              oldValue: AuditDetailLine.formatValue(change['old']),
              value: AuditDetailLine.formatValue(change['new']),
            ));
          }
        }
      } else if (oldData.isNotEmpty || newData.isNotEmpty) {
        // Comparer old vs new, ignorer les champs non modifiés
        final allKeys = {...oldData.keys, ...newData.keys};
        const ignoredKeys = {'id', 'created_at', 'updated_at', 'slug', 'is_active'};
        for (final key in allKeys) {
          if (ignoredKeys.contains(key)) continue;
          final oldVal = oldData[key];
          final newVal = newData[key];
          if (oldVal.toString() != newVal.toString()) {
            lines.add(AuditDetailLine(
              label: AuditDetailLine.friendlyFieldName(key),
              oldValue: AuditDetailLine.formatValue(oldVal),
              value: AuditDetailLine.formatValue(newVal),
            ));
          }
        }
      }
      return lines;
    }

    return [];
  }
}

/// Représente une ligne de détail à afficher dans le tile d'audit.
class AuditDetailLine {
  final String label;
  final String? oldValue;
  final String value;
  final bool isNew;

  const AuditDetailLine({
    required this.label,
    this.oldValue,
    required this.value,
    this.isNew = false,
  });

  static String friendlyFieldName(String key) {
    const map = <String, String>{
      'full_name': 'Nom',
      'name': 'Nom',
      'position': 'Poste',
      'team_name': 'Équipe',
      'jersey_number': 'N° maillot',
      'nationality': 'Nationalité',
      'height_cm': 'Taille (cm)',
      'weight_kg': 'Poids (kg)',
      'biography': 'Biographie',
      'profile_image_url': 'Photo',
      'cover_image_url': 'Couverture',
      'sport_id': 'Sport',
      'competition_id': 'Compétition',
      'years_experience': 'Années d\'exp.',
      'certifications': 'Certifications',
      'photo_url': 'Photo',
      'contact_email': 'Email',
      'level': 'Niveau',
      'role': 'Rôle',
    };
    return map[key] ?? key.replaceAll('_', ' ');
  }

  static String formatValue(dynamic val) {
    if (val == null) return '—';
    if (val is List) return val.join(', ');
    final s = val.toString();
    if (s.isEmpty) return '—';
    // Tronquer les valeurs trop longues (URL, biographie)
    if (s.length > 60) return '${s.substring(0, 57)}...';
    return s;
  }
}
