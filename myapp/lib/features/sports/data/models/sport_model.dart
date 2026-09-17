class SportModel {
  final String id;
  final String name;
  final String slug;
  final String? iconEmoji;
  final String? coverImageUrl;
  final bool hasAmateurs;
  final bool hasAcademies;
  final bool hasCoaches;

  SportModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconEmoji,
    this.coverImageUrl,
    this.hasAmateurs = false,
    this.hasAcademies = false,
    this.hasCoaches = false,
  });

  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconEmoji: json['icon_emoji'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      hasAmateurs: json['has_amateurs'] as bool? ?? false,
      hasAcademies: json['has_academies'] as bool? ?? false,
      hasCoaches: json['has_coaches'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon_emoji': iconEmoji,
      'cover_image_url': coverImageUrl,
      'has_amateurs': hasAmateurs,
      'has_academies': hasAcademies,
      'has_coaches': hasCoaches,
    };
  }
}