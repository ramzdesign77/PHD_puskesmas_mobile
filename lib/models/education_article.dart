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

  String? get imageUrl => _resolveImageUrl(image, apiBaseUri);

  factory EducationArticle.fromJson(
    Map<String, dynamic> json,
    [Uri? apiBaseUri]
  ) {
    final content = _stringValue(json['content'] ?? json['description']);
    final excerpt = _stringValue(json['excerpt']);
    final imageValue = json['image'] ?? json['image_url'];

    return EducationArticle(
      id: _parseId(json['id']),
      title: _stringValue(json['title']),
      category: _stringValue(json['category']),
      excerpt: excerpt.isEmpty ? content : excerpt,
      content: content,
      image: imageValue is String ? imageValue : null,
      apiBaseUri: apiBaseUri,
    );
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static int _parseId(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _resolveImageUrl(String? image, Uri? apiBaseUri) {
    final value = image?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final imageUri = Uri.tryParse(value);
    if (imageUri == null) {
      return null;
    }

    if (imageUri.hasScheme) {
      if ((imageUri.scheme == 'http' || imageUri.scheme == 'https') &&
          imageUri.hasAuthority) {
        if (apiBaseUri != null &&
            _isLoopbackHost(imageUri.host) &&
            !_isLoopbackHost(apiBaseUri.host) &&
            imageUri.pathSegments.contains('storage')) {
          return apiBaseUri
              .replace(
                path: imageUri.path,
                query: imageUri.hasQuery ? imageUri.query : null,
                fragment: imageUri.hasFragment ? imageUri.fragment : null,
              )
              .toString();
        }

        return imageUri.toString();
      }

      return null;
    }

    if (apiBaseUri == null) {
      return null;
    }

    if (imageUri.hasAuthority) {
      return apiBaseUri.resolveUri(imageUri).toString();
    }

    var imagePath = imageUri.path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    if (imagePath.startsWith('public/')) {
      imagePath = imagePath.substring('public/'.length);
    }
    if (!imagePath.startsWith('storage/')) {
      imagePath = 'storage/$imagePath';
    }

    final baseSegments = apiBaseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (baseSegments.isNotEmpty && baseSegments.last == 'api') {
      baseSegments.removeLast();
    }
    final basePath = baseSegments.isEmpty
        ? '/'
        : '/${baseSegments.join('/')}/';
    final storageBaseUri = apiBaseUri.replace(
      path: basePath,
      query: null,
      fragment: null,
    );

    return storageBaseUri
        .resolve(imagePath)
        .replace(
          query: imageUri.hasQuery ? imageUri.query : null,
          fragment: imageUri.hasFragment ? imageUri.fragment : null,
        )
        .toString();
  }

  static bool _isLoopbackHost(String host) {
    final normalizedHost = host.toLowerCase();

    return normalizedHost == 'localhost' ||
        normalizedHost == '127.0.0.1' ||
        normalizedHost == '::1';
  }
}
