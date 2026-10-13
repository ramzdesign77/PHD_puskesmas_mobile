class EducationArticle {
  const EducationArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.excerpt,
    required this.content,
    this.image,
    this.apiBaseUri,
  });

  final int id;
  final String title;
  final String category;
  final String excerpt;
  final String content;
  final String? image;
  final Uri? apiBaseUri;

  // Memanggil getter imageUrl yang diolah secara bersih
  String? get imageUrl => _resolveImageUrl(image, apiBaseUri);

  factory EducationArticle.fromJson(
    Map<String, dynamic> json, [
    Uri? apiBaseUri,
  ]) {
    final content = _stringValue(json['content'] ?? json['description']);
    final excerpt = _stringValue(json['excerpt']);

    return EducationArticle(
      id: _parseId(json['id']),
      title: _stringValue(json['title']),
      category: _stringValue(json['category']),
      excerpt: excerpt.isEmpty ? content : excerpt,
      content: content,
      image: json['image'] ?? json['image_url'],
      apiBaseUri: apiBaseUri,
    );
  }

  // Mengolah URL gambar agar selalu aman dari CORS
  static String? _resolveImageUrl(String? rawImage, Uri? apiBaseUri) {
    if (rawImage == null || rawImage.trim().isEmpty) return null;

    final value = rawImage.trim();

    // 1. Jika dari API berupa URL lengkap (http://localhost:8000/storage/educations/foto.jpg)
    if (value.startsWith('http://') || value.startsWith('https://')) {
      // Ubah '/storage/' menjadi '/api/get-image/' agar lolos aturan CORS
      if (value.contains('/storage/')) {
        return value.replaceFirst('/storage/', '/api/get-image/');
      }
      return value;
    }

    // 2. Jika berupa path relatif (educations/foto.jpg), gabungkan dengan base URL API
    if (apiBaseUri != null) {
      final filename = value.contains('/') ? value.split('/').last : value;
      return apiBaseUri.resolve('/api/get-image/$filename').toString();
    }

    return null;
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static int _parseId(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
