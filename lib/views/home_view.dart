import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/education_article.dart';
import '../services/api_service.dart';
import 'article_detail_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.apiService,
    required this.onOpenReports,
  });

  final ApiService apiService;
  final VoidCallback onOpenReports;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<List<EducationArticle>> _articles;

  @override
  void initState() {
    super.initState();
    _articles = widget.apiService.getArticles();
  }

  Future<void> _refresh() async {
    final refreshed = widget.apiService.getArticles();
    setState(() => _articles = refreshed);
    await refreshed;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              sliver: SliverList.list(
                children: [
                  const _BrandRow(),
                  const SizedBox(height: 22),
                  _WelcomePanel(onOpenReports: widget.onOpenReports),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edukasi kesehatan',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Panduan air bersih dan sanitasi lingkungan',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 15),
                  FutureBuilder<List<EducationArticle>>(
                    future: _articles,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _LoadError(
                          message: snapshot.error.toString(),
                          onRetry: _refresh,
                        );
                      }

                      final articles = snapshot.data ?? [];
                      if (articles.isEmpty) {
                        return const _EmptyArticles();
                      }

                      return Column(
                        children: articles
                            .map(
                              (article) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ArticleTile(
                                  article: article,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ArticleDetailView(article: article),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Klinik Sanitasi - Puskesmas Sumbersari',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.primary,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KLINIK SANITASI',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            const Text(
              'PUSKESMAS SUMBERSARI',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        const Icon(Icons.water_drop_outlined, color: AppColors.primary),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onOpenReports});

  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 27),
          const SizedBox(height: 17),
          Text(
            'Lingkungan sehat,\nberawal dari kita.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Akses informasi sanitasi dan sampaikan masalah lingkungan kepada petugas kami.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 19),
          FilledButton.icon(
            onPressed: onOpenReports,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 19),
            label: const Text('Buat laporan'),
          ),
        ],
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final EducationArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: article.imageUrl == null
                      ? const ColoredBox(
                          color: Color(0xFFF1E9E7),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: AppColors.primary,
                            size: 31,
                          ),
                        )
                      : Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFF1E9E7),
                            child: Icon(
                              Icons.water_drop_outlined,
                              color: AppColors.primary,
                              size: 31,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyArticles extends StatelessWidget {
  const _EmptyArticles();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Text(
          'Belum ada artikel edukasi.',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_outlined, color: AppColors.muted),
          const SizedBox(height: 8),
          const Text('Artikel belum dapat dimuat.'),
          const SizedBox(height: 5),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
