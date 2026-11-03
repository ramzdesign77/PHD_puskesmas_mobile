import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _campaignPrimary = Color(0xFF0284C7);
const _campaignSecondary = Color(0xFF06B6D4);
const _campaignAccent = Color(0xFF38BDF8);
const _campaignPillars = [
  (
    title: 'Stop Buang Air Besar Sembarangan',
    description: 'Gunakan jamban sehat dan pastikan tinja tidak mencemari lingkungan maupun sumber air.',
    icon: Icons.wc_outlined,
  ),
  (
    title: 'Cuci Tangan Pakai Sabun',
    description: 'Biasakan mencuci tangan dengan sabun dan air mengalir pada waktu-waktu penting.',
    icon: Icons.wash_outlined,
  ),
  (
    title: 'Pengelolaan Air Minum dan Makanan Rumah Tangga',
    description: 'Jaga air minum tetap aman dan kelola makanan secara bersih, tertutup, serta higienis.',
    icon: Icons.water_drop_outlined,
  ),
  (
    title: 'Pengamanan Sampah Rumah Tangga',
    description: 'Pilah dan kelola sampah dengan benar agar tidak menjadi sumber penyakit dan pencemaran.',
    icon: Icons.delete_outline_rounded,
  ),
  (
    title: 'Pengamanan Limbah Cair Rumah Tangga',
    description: 'Salurkan dan kelola air limbah agar tidak menggenang atau mencemari lingkungan.',
    icon: Icons.recycling_outlined,
  ),
];

class WaterCampaignCarousel extends StatefulWidget {
  const WaterCampaignCarousel({super.key});

  @override
  State<WaterCampaignCarousel> createState() => _WaterCampaignCarouselState();
}

class _WaterCampaignCarouselState extends State<WaterCampaignCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 256,
          child: PageView.builder(
            key: const Key('campaign_carousel_page_view'),
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            itemCount: _campaignPillars.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final pillar = _campaignPillars[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _WaterCampaignCard(
                  index: index,
                  title: pillar.title,
                  description: pillar.description,
                  icon: pillar.icon,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < _campaignPillars.length; index++)
              Semantics(
                button: true,
                selected: index == _currentPage,
                label: 'Pilar ${index + 1} dari ${_campaignPillars.length}',
                child: InkWell(
                  key: Key('campaign_page_indicator_$index'),
                  onTap: () => _goToPage(index),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: index == _currentPage ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? _campaignPrimary
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WaterCampaignCard extends StatelessWidget {
  const _WaterCampaignCard({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int index;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_campaignPrimary, _campaignSecondary, _campaignAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 20,
                right: 24,
                child: _GlassBubble(size: 78),
              ),
              const Positioned(
                right: 98,
                bottom: 20,
                child: _GlassBubble(size: 38),
              ),
              Positioned(
                right: -14,
                bottom: -34,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 132,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'KAMPANYE SANITASI',
                        style: TextStyle(
                          fontFamily: AppTheme.headlineFontFamily,
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.headlineFontFamily,
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          icon,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Pilar ${index + 1} dari ${_campaignPillars.length}',
                          style: TextStyle(
                            fontFamily: AppTheme.headlineFontFamily,
                            color: Colors.white.withValues(alpha: 0.94),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
    );
  }
}

class _GlassBubble extends StatelessWidget {
  const _GlassBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}
