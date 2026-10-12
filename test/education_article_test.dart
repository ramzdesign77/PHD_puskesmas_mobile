import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/models/education_article.dart';

void main() {
  group('EducationArticle.fromJson', () {
    final apiBaseUri = Uri.parse('https://sanitasi.example/api/');

    test('preserves an absolute image URL from the API', () {
      final article = EducationArticle.fromJson({
        'id': 1,
        'title': 'Air bersih',
        'category': 'Air & Sanitasi',
        'excerpt': 'Panduan air bersih.',
        'content': 'Informasi lengkap tentang air bersih.',
        'image': 'https://cdn.example/images/air.jpg',
      }, apiBaseUri);

      expect(article.imageUrl, 'https://cdn.example/images/air.jpg');
    });

    test('uses the API host for absolute loopback storage URLs', () {
      final article = EducationArticle.fromJson({
        'id': 5,
        'title': 'Gambar lokal',
        'category': 'PHBS',
        'excerpt': 'Artikel.',
        'content': 'Informasi lengkap untuk pengujian URL gambar.',
        'image': 'http://localhost:8000/storage/educations/gambar.jpg',
      }, Uri.parse('http://192.168.1.10:8000/api/'));

      expect(
        article.imageUrl,
        'http://192.168.1.10:8000/storage/educations/gambar.jpg',
      );
    });

    test('resolves a Laravel storage path outside the API prefix', () {
      final article = EducationArticle.fromJson({
        'id': '2',
        'title': 'Sanitasi',
        'category': 'PHBS',
        'content': 'Informasi lengkap tentang sanitasi.',
        'image': 'educations/sanitasi.jpg',
      }, apiBaseUri);

      expect(
        article.imageUrl,
        'https://sanitasi.example/storage/educations/sanitasi.jpg',
      );
      expect(article.id, 2);
      expect(article.excerpt, article.content);
    });

    test('keeps an existing storage path and returns null for no image', () {
      final article = EducationArticle.fromJson({
        'id': 3,
        'title': 'Pengelolaan sampah',
        'category': 'PHBS',
        'excerpt': 'Artikel.',
        'content': 'Informasi lengkap tentang pengelolaan sampah.',
        'image': '/storage/educations/sampah.jpg',
      }, apiBaseUri);
      final articleWithoutImage = EducationArticle.fromJson({
        'id': 4,
        'title': 'Artikel tanpa gambar',
        'category': 'PHBS',
        'excerpt': 'Artikel.',
        'content': 'Informasi lengkap tanpa gambar.',
      }, apiBaseUri);

      expect(
        article.imageUrl,
        'https://sanitasi.example/storage/educations/sampah.jpg',
      );
      expect(articleWithoutImage.imageUrl, isNull);
    });
  });
}
