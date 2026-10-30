import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../models/education_article.dart';

class ArticleDetailView extends StatefulWidget {
  const ArticleDetailView({super.key, required this.article});

  final EducationArticle article;

  @override
  State<ArticleDetailView> createState() => _ArticleDetailViewState();
}

class _ArticleDetailViewState extends State<ArticleDetailView> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 200 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. SLIVER APP BAR (Efek Parallax & Header Melayang)
          SliverAppBar(
            expandedHeight: hasImage ? 350.0 : 120.0,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            elevation: _isScrolled ? 4 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _GlassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              titlePadding: const EdgeInsets.only(
                left: 50,
                bottom: 16,
                right: 50,
              ),
              title: AnimatedOpacity(
                opacity: _isScrolled ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.article.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              background: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.primary),
                        ),
                        // Gradien gelap di bagian bawah gambar agar menyatu dengan konten
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const ColoredBox(color: AppColors.primary),
            ),
          ),

          // 2. KONTEN ARTIKEL (Overlapping Card)
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30), // Mengangkat konten ke atas gambar
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle kecil di atas card
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Animasi Berurutan (Staggered Animation)
                    _AnimatedEntry(
                      delay: 100,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              widget.article.category.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _AnimatedEntry(
                      delay: 250,
                      child: Text(
                        widget.article.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _AnimatedEntry(
                      delay: 400,
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFF1E9E7),
                            child: Icon(
                              Icons.health_and_safety,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Tim Medis Sanitasi',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              Text(
                                'Puskesmas Sumbersari',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _AnimatedEntry(delay: 500, child: Divider(height: 1)),
                    const SizedBox(height: 24),

                    // Paragraf Konten dengan Drop Cap style & Line Height elegan
                    _AnimatedEntry(
                      delay: 650,
                      child: Text(
                        widget.article.content,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: const Color(0xFF333333),
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

    );
  }
}

// =========================================================================
// WIDGET BANTUAN (HELPER WIDGETS) UNTUK ANIMASI & EFEK KOMPLEKS
// =========================================================================

/// Widget untuk efek kaca buram (Glassmorphism) pada tombol header
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget Cerdas untuk Animasi Berurutan (Staggered Fade & Slide In)
class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child, required this.delay});
  final Widget child;
  final int delay;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    // Tahan animasi sesuai delay, lalu jalankan sekali saja
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        setState(() => _show = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kita gunakan AnimatedOpacity dan AnimatedContainer
    // agar ukuran asli konten tetap terbaca oleh ScrollView sejak awal,
    // sehingga scroll tidak akan pernah melompat ke atas.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      opacity: _show ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _show ? 0 : 30,
          0,
        ), // Meluncur 30px dari bawah
        child: widget.child,
      ),
    );
  }
}
