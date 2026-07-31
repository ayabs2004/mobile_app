class CompetitionModel {
  final String id;
  final String sportId;
  final String name;
  final String slug;
  final String? level; // "Professional", "Amateur"... tag libre, optionnel

  CompetitionModel({
    required this.id,
    required this.sportId,
    required this.name,
    required this.slug,
    this.level,
  });

  factory CompetitionModel.fromJson(Map<String, dynamic> json) {
    return CompetitionModel(
      id: json['id'] as String,
      sportId: json['sport_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'sport_id': sportId,
        'name': name,
        'slug': slug,
        'level': level,
      };
}
