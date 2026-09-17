class FantasyRoundModel {
  final String id;
  final String name;
  final String status; // 'open' | 'closed'
  final double budget;
  final int maxPlayers;
  final int maxPerClub;
  final String? sportId; // sport auquel ce round est rattaché (foot / hand)
  final DateTime? createdAt;

  FantasyRoundModel({
    required this.id,
    required this.name,
    required this.status,
    required this.budget,
    required this.maxPlayers,
    required this.maxPerClub,
    this.sportId,
    this.createdAt,
  });

  bool get isOpen => status == 'open';

  factory FantasyRoundModel.fromJson(Map<String, dynamic> json) {
    return FantasyRoundModel(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'open',
      budget: (json['budget'] as num?)?.toDouble() ?? 100.0,
      maxPlayers: json['max_players'] as int? ?? 11,
      maxPerClub: json['max_per_club'] as int? ?? 3,
      sportId: json['sport_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'status': status,
      'budget': budget,
      'max_players': maxPlayers,
      'max_per_club': maxPerClub,
      'sport_id': sportId,
    };
  }
}
