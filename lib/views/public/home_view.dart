import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wave/wave.dart';

import '../../constants/app_colors.dart';
import '../../models/education_article.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/educational_slogan_card.dart';
import '../../widgets/ocean_widgets.dart';
import '../../widgets/water_campaign_carousel.dart';
import 'article_detail_view.dart';

const _heroHeaderRadius = 28.0;
const _oceanBlue = AppColors.primary;
const _deepOceanBlue = AppColors.primaryDark;
const _paleBlue = AppColors.softBlue;
const _offWhiteBlue = Color(0xFFF8FAFC);
const _homeBodyFontFamily = 'Montserrat';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.apiService,
    required this.greetingName,
    required this.onOpenReports,
    required this.onOpenTracking,
  });

  final ApiService apiService;
  final String greetingName;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenTracking;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const _articlesPerPage = 3;
  final _articlesSectionKey = GlobalKey();
  late Future<List<EducationArticle>> _articlesFuture;
  int _currentArticlePage = 0;

  @override
  void initState() {
    super.initState();
    _articlesFuture = widget.apiService.getArticles();
  }

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    return Theme(
      data: inheritedTheme.copyWith(
        textTheme: inheritedTheme.textTheme.apply(
          fontFamily: _homeBodyFontFamily,
        ),
        primaryTextTheme: inheritedTheme.primaryTextTheme.apply(
          fontFamily: _homeBodyFontFamily,
        ),
      ),
      child: Scaffold(
        backgroundColor: _offWhiteBlue,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderAndGreeting(),
                    const SizedBox(height: 18),
                    _buildHighlights(),
                    const SizedBox(height: 28),
                    _buildSectionHeading(
                      'Layanan',
                      subtitle: 'Akses cepat untuk kebutuhan sanitasi Anda',
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 22),
                    const WaterCampaignCarousel(),
                    const SizedBox(height: 18),
                    const EducationalSloganCard(),
                    const SizedBox(height: 28),
                    Container(
                      key: _articlesSectionKey,
                      child: FutureBuilder<List<EducationArticle>>(
                        future: _articlesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: WaterLoadingIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return _LoadError(
                              message: 'Gagal memuat data: ${snapshot.error}',
                              onRetry: () async {
                                setState(() {
                                  _currentArticlePage = 0;
                                  _articlesFuture = widget.apiService
                                      .getArticles();
                                });
                              },
                            );
                          }

                          final articles = snapshot.data ?? [];
                          if (articles.isEmpty) {
                            return const _EmptyArticles();
                          }

                          final totalPages =
                              (articles.length + _articlesPerPage - 1) ~/
                              _articlesPerPage;
                          final currentPage = _currentArticlePage
                              .clamp(0, totalPages - 1)
                              .toInt();
                          final firstArticleIndex =
                              currentPage * _articlesPerPage;
                          final pageArticles = articles
                              .skip(firstArticleIndex)
                              .take(_articlesPerPage)
                              .toList(growable: false);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeading(
                                'Artikel Edukasi',
                                subtitle:
                                    'Wawasan praktis untuk hidup lebih sehat',
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: SizedBox(
                                  key: Key(
                                    'education_article_page_area_$currentPage',
                                  ),
                                  height: _ArticleTile.cardHeight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final article in pageArticles)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 12,
                                            ),
                                            child: _ArticleTile(
                                              imageUrl: article.imageUrl,
                                              category: article.category,
                                              title: article.title,
                                              subtitle: article.excerpt,
                                              onTap: () => Navigator.of(context)
                                                  .push(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ArticleDetailView(
                                                            article: article,
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (totalPages > 1) ...[
                                const SizedBox(height: 4),
                                _EducationPagination(
                                  currentPage: currentPage,
                                  totalPages: totalPages,
                                  onPageChanged: (page) => setState(
                                    () => _currentArticlePage = page,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        'Klinik Sanitasi - Puskesmas Sumbersari',
                        style: TextStyle(
                          fontFamily: _homeBodyFontFamily,
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAndGreeting() {
    return Container(
      height: 374,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_heroHeaderRadius),
        boxShadow: [
          BoxShadow(
            color: _deepOceanBlue.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_heroHeaderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF003B67),
                    Color(0xFF0277BD),
                    Color(0xFF06B6D4),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                key: const Key('home_hero_wave_clip'),
                borderRadius: BorderRadius.circular(_heroHeaderRadius),
                child: WaveWidget(
                  config: CustomConfig(
                    colors: const [
                      Color(0x3306B6D4),
                      Color(0x4D06B6D4),
                      Color(0x6606B6D4),
                    ],
                    durations: const [12000, 9000, 7000],
                    heightPercentages: const [0.42, 0.54, 0.66],
                  ),
                  size: Size.infinite,
                  waveAmplitude: 24,
                  waveFrequency: 1.4,
                ),
              ),
            ),
            Positioned(
              top: -34,
              right: -22,
              child: Icon(
                Icons.water_drop_rounded,
                size: 220,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const Positioned(top: 44, right: 36, child: _HeroBubble(size: 66)),
            const Positioned(
              top: 118,
              right: 112,
              child: _HeroBubble(size: 24),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xAA002B4A), Color(0x00002B4A)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.32),
                          ),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KLINIK SANITASI',
                              style: TextStyle(
                                fontFamily: _homeBodyFontFamily,
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'Halo, ${widget.greetingName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: _homeBodyFontFamily,
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Lacak laporan',
                        onPressed: widget.onOpenTracking,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.track_changes_rounded, size: 19),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Sanitasi sehat,\nkeluarga kuat.',
                    style: TextStyle(
                      fontFamily: AppTheme.headlineFontFamily,
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bersama wujudkan lingkungan bersih dan bebas penyakit.',
                    style: TextStyle(
                      fontFamily: _homeBodyFontFamily,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.onOpenReports,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Buat laporan'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _deepOceanBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: _homeBodyFontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenTracking,
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Lacak laporan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: _homeBodyFontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights() {
    return Row(
      children: [
        Expanded(
          child: _HighlightCard(
            icon: Icons.water_drop_outlined,
            value: '05',
            label: 'Pilar STBM',
            tint: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HighlightCard(
            icon: Icons.grid_view_rounded,
            value: '03',
            label: 'Akses layanan',
            tint: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF15803D),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title, {required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: _homeBodyFontFamily,
            color: AppColors.muted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final items = [
      (
        icon: Icons.add_location_alt_outlined,
        label: 'Lapor Pengaduan',
        description: 'Sampaikan masalah sanitasi di lingkungan Anda.',
        onTap: widget.onOpenReports,
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Laporan Saya',
        description: 'Pantau perkembangan laporan yang sudah dikirim.',
        onTap: widget.onOpenTracking,
      ),
      (
        icon: Icons.menu_book_outlined,
        label: 'Artikel STBM',
        description: 'Baca panduan praktis sanitasi dan kesehatan.',
        onTap: _showAllArticles,
      ),
    ];

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(19),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _paleBlue,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(item.icon, color: _oceanBlue, size: 22),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontFamily: AppTheme.headlineFontFamily,
                                color: AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: _homeBodyFontFamily,
                                color: AppColors.muted,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAllArticles() {
    final sectionContext = _articlesSectionKey.currentContext;
    if (sectionContext == null) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class _HeroBubble extends StatelessWidget {
  const _HeroBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: Color(0xFF0F172A),
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: _homeBodyFontFamily,
                    color: AppColors.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// Card Artikel Edukasi
// ===========================================================
class _ArticleTile extends StatelessWidget {
  static const cardHeight = 258.0;

  const _ArticleTile({
    required this.imageUrl,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String? imageUrl;
  final String category;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  Widget _imageFallback() {
    return const ColoredBox(
      color: _paleBlue,
      child: Center(
        child: Icon(Icons.water_drop_outlined, color: _oceanBlue, size: 42),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(24));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: _oceanBlue.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 224,
            height: cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl == null || imageUrl!.isEmpty
                    ? _imageFallback()
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return ColoredBox(
                            color: _paleBlue,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _oceanBlue,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            (loadingProgress
                                                    .expectedTotalBytes ??
                                                1)
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => _imageFallback(),
                      ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0000213A),
                        Color(0x3300213A),
                        Color(0xE600213A),
                      ],
                      stops: [0, 0.42, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: _homeBodyFontFamily,
                            color: _deepOceanBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.headlineFontFamily,
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _homeBodyFontFamily,
                          fontSize: 10,
                          height: 1.35,
                          color: Color(0xFFEAF8FF),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: Color(0xFFD8F3FF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: _homeBodyFontFamily,
                                fontSize: 9,
                                color: Color(0xFFEAF8FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_outward_rounded,
                            size: 15,
                            color: Color(0xFFEAF8FF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EducationPagination extends StatelessWidget {
  const _EducationPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final visiblePageCount = totalPages < 3 ? totalPages : 3;
    var firstVisiblePage = currentPage - 1;
    if (firstVisiblePage < 0) firstVisiblePage = 0;
    if (firstVisiblePage + visiblePageCount > totalPages) {
      firstVisiblePage = totalPages - visiblePageCount;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        children: [
          _PaginationArrow(
            controlKey: const Key('education_previous_page'),
            icon: Icons.chevron_left_rounded,
            tooltip: 'Halaman sebelumnya',
            enabled: currentPage > 0,
            onPressed: () => onPageChanged(currentPage - 1),
          ),
          if (firstVisiblePage > 0) const _PaginationEllipsis(),
          for (
            var page = firstVisiblePage;
            page < firstVisiblePage + visiblePageCount;
            page++
          )
            _PaginationPage(
              page: page,
              selected: page == currentPage,
              onPressed: () => onPageChanged(page),
            ),
          if (firstVisiblePage + visiblePageCount < totalPages)
            const _PaginationEllipsis(),
          _PaginationArrow(
            controlKey: const Key('education_next_page'),
            icon: Icons.chevron_right_rounded,
            tooltip: 'Halaman berikutnya',
            enabled: currentPage < totalPages - 1,
            onPressed: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PaginationArrow extends StatelessWidget {
  const _PaginationArrow({
    required this.controlKey,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final Key controlKey;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: controlKey,
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      constraints: const BoxConstraints.tightFor(width: 38, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: enabled ? const Color(0xFFF1F5F9) : Colors.transparent,
        foregroundColor: enabled
            ? const Color(0xFF64748B)
            : const Color(0xFFCBD5E1),
        disabledForegroundColor: const Color(0xFFCBD5E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class _PaginationPage extends StatelessWidget {
  const _PaginationPage({
    required this.page,
    required this.selected,
    required this.onPressed,
  });

  final int page;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 40,
      child: TextButton(
        key: Key('education_page_$page'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected
              ? const Color(0xFF0284C7)
              : const Color(0xFFF1F5F9),
          foregroundColor: selected ? Colors.white : const Color(0xFF64748B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PaginationEllipsis extends StatelessWidget {
  const _PaginationEllipsis();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      child: Text(
        '…',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _homeBodyFontFamily,
          color: Color(0xFF64748B),
          fontSize: 13,
        ),
      ),
    );
  }
}

// ===========================================================
// State kosong & error
// ===========================================================
class _EmptyArticles extends StatelessWidget {
  const _EmptyArticles();

  @override
  Widget build(BuildContext context) {
    return const WaterEmptyState(
      icon: Icons.menu_book_outlined,
      title: 'Belum ada artikel edukasi',
      message: 'Artikel sanitasi terbaru akan tampil di sini.',
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _oceanBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
