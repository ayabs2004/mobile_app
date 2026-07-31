class SportModel {
  final String id;
  final String name;
  final String slug;
  final String? iconEmoji;
  final String? coverImageUrl;

  SportModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconEmoji,
    this.coverImageUrl,
  });

  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconEmoji: json['icon_emoji'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}