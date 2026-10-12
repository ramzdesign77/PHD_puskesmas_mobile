import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/education_article.dart';

class ArticleDetailView extends StatelessWidget {
  const ArticleDetailView({super.key, required this.article});

  final EducationArticle article;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.imageUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Edukasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: imageUrl == null
                  ? _imageFallback()
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, loadingProgress) =>
                          loadingProgress == null ? child : _imageFallback(),
                      errorBuilder: (_, _, _) => _imageFallback(),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            article.category.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 14),
          Text(
            article.content,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(height: 1.65, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return const ColoredBox(
      color: Color(0xFFF1E9E7),
      child: Center(
        child: Icon(
          Icons.water_drop_outlined,
          color: AppColors.primary,
          size: 48,
        ),
      ),
    );
  }
}
