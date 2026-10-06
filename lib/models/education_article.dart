class EducationArticle {
  const EducationArticle({
    required this.id,
    required this.title,
    required this.slug,
    required this.category,
    required this.excerpt,
    required this.content,
    this.imageUrl,
    this.publishedAt,
  });

  final int id;
  final String title;
  final String slug;
  final String category;
  final String excerpt;
  final String content;
  final String? imageUrl;
  final DateTime? publishedAt;

  factory EducationArticle.fromJson(Map<String, dynamic> json, Uri baseUri) {
    final image = json['image'] as String?;

    return EducationArticle(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      category: json['category'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: image == null ? null : baseUri.resolve(image).toString(),
      publishedAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
