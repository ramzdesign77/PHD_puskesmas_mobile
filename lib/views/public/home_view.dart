import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/education_article.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocean_widgets.dart';
import 'article_detail_view.dart';

const _oceanBlue = AppColors.primary;
const _deepOceanBlue = AppColors.primaryDark;
const _aquaBlue = AppColors.primaryLight;
const _paleBlue = AppColors.softBlue;
const _offWhiteBlue = Color(0xFFF4F9F9);

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
  final _articlesSectionKey = GlobalKey();
  late Future<List<EducationArticle>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = widget.apiService.getArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhiteBlue,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderAndGreeting(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Layanan',
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ).asHeading,
                        ),
                        const SizedBox(height: 14),
                        _buildQuickActions(),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Info Kesehatan',
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ).asHeading,
                            ),
                            TextButton(
                              onPressed: _showAllArticles,
                              style: TextButton.styleFrom(
                                foregroundColor: _oceanBlue,
                              ),
                              child: const Text('Lihat Semua'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const _AnnouncementCard(),
                        const SizedBox(height: 18),
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
                                  message:
                                      'Gagal memuat data: ${snapshot.error}',
                                  onRetry: () async {
                                    setState(() {
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

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Artikel Edukasi',
                                    style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ).asHeading,
                                  ),
                                  const SizedBox(height: 12),
                                  ...articles.map(
                                    (article) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _ArticleTile(
                                        imageUrl: article.imageUrl,
                                        category: article.category,
                                        title: article.title,
                                        subtitle: article.excerpt,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ArticleDetailView(
                                              article: article,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'Klinik Sanitasi - Puskesmas Sumbersari',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAndGreeting() {
    return SizedBox(
      height: 430,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DynamicWaterHeader(
              height: 356,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 32,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang,',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.greetingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ).asHeading,
                ),
                const SizedBox(height: 5),
                Text(
                  'KLINIK SANITASI',
                  style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 126,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  child: InkWell(
                    onTap: widget.onOpenTracking,
                    splashColor: Colors.white.withValues(alpha: 0.18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: _oceanBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Pantau status laporan sanitasi Anda',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 196,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _oceanBlue.withValues(alpha: 0.17),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -8,
                          top: 8,
                          child: Icon(
                            Icons.water_drop_rounded,
                            color: _aquaBlue.withValues(alpha: 0.1),
                            size: 76,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Laporan Sanitasi Baru',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                                color: AppColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ).asHeading,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Sampaikan masalah sanitasi di lingkungan Anda.',
                              style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: widget.onOpenReports,
                                icon: const Icon(Icons.add_rounded, size: 19),
                                label: const Text('Buat Laporan'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _deepOceanBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final items = [
      (
        icon: Icons.add_location_alt_outlined,
        label: 'Lapor Pengaduan',
        onTap: widget.onOpenReports,
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Laporan Saya',
        onTap: widget.onOpenTracking,
      ),
      (
        icon: Icons.menu_book_outlined,
        label: 'Artikel STBM',
        onTap: _showAllArticles,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: _aquaBlue.withValues(alpha: 0.18),
                  highlightColor: _aquaBlue.withValues(alpha: 0.08),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 116),
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _oceanBlue.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _paleBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: _oceanBlue, size: 22),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                            color: AppColors.ink,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_deepOceanBlue, _oceanBlue, _aquaBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            top: 4,
            child: Icon(
              Icons.water_drop_outlined,
              color: Colors.white.withValues(alpha: 0.24),
              size: 72,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(
              Icons.eco_outlined,
              color: Colors.white.withValues(alpha: 0.22),
              size: 62,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PENGUMUMAN',
                  style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lingkungan Sehat,\nBerawal Dari Kita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ).asHeading,
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
            height: 196,
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
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _paleBlue.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                        color: _deepOceanBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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
                        style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          shadows: const [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ).asHeading,
                      ),
                      const SizedBox(height: 7),
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
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppTheme.bodyFontFamily,
                                fontSize: 11,
                                color: const Color(0xFFEAF8FF),
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
