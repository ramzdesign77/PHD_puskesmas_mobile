import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _campaignPrimary = Color(0xFF0284C7);
const _campaignBodyFontFamily = 'Montserrat';
const _pilarThemes = <_PilarTheme>[
  (
    colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    ornament: _WaterOrnament.drop,
  ),
  (
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    ornament: _WaterOrnament.bubbles,
  ),
  (
    colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    ornament: _WaterOrnament.waveLines,
  ),
  (
    colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    ornament: _WaterOrnament.flowingWater,
  ),
  (
    colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    ornament: _WaterOrnament.stackedWaves,
  ),
];

typedef _PilarTheme = ({
  List<Color> colors,
  Alignment begin,
  Alignment end,
  _WaterOrnament ornament,
});

enum _WaterOrnament { drop, bubbles, waveLines, flowingWater, stackedWaves }

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
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kampanye Sanitasi',
                    style: TextStyle(
                      fontFamily: AppTheme.headlineFontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '5 Pilar STBM',
                    style: TextStyle(
                      fontFamily: _campaignBodyFontFamily,
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Pilar sebelumnya',
              onPressed: _currentPage == 0
                  ? null
                  : () => _goToPage(_currentPage - 1),
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF0284C7),
                disabledForegroundColor: const Color(0xFFCBD5E1),
                fixedSize: const Size(36, 36),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Pilar berikutnya',
              onPressed: _currentPage == _campaignPillars.length - 1
                  ? null
                  : () => _goToPage(_currentPage + 1),
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF0284C7),
                disabledForegroundColor: const Color(0xFFCBD5E1),
                fixedSize: const Size(36, 36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
    final theme = _getPilarTheme(index);
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
          key: Key('campaign_card_gradient_$index'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.colors,
              begin: theme.begin,
              end: theme.end,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: Key('campaign_card_ornament_$index'),
                    painter: _WaterOrnamentPainter(theme.ornament),
                  ),
                ),
              ),
              if (theme.ornament == _WaterOrnament.drop)
                Positioned(
                  right: -14,
                  bottom: -34,
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 132,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              if (theme.ornament == _WaterOrnament.bubbles) ...[
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
                const Positioned(
                  top: 80,
                  right: 74,
                  child: _GlassBubble(size: 24),
                ),
              ],
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
                        fontFamily: _campaignBodyFontFamily,
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

_PilarTheme _getPilarTheme(int index) => _pilarThemes[index];

class _WaterOrnamentPainter extends CustomPainter {
  const _WaterOrnamentPainter(this.ornament);

  final _WaterOrnament ornament;

  @override
  void paint(Canvas canvas, Size size) {
    switch (ornament) {
      case _WaterOrnament.drop:
      case _WaterOrnament.bubbles:
        return;
      case _WaterOrnament.waveLines:
        _paintWaveLines(canvas, size);
        break;
      case _WaterOrnament.flowingWater:
        _paintFlowingWater(canvas, size);
        break;
      case _WaterOrnament.stackedWaves:
        _paintStackedWaves(canvas, size);
        break;
    }
  }

  void _paintWaveLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var index = 0; index < 3; index++) {
      final y = size.height * (0.32 + index * 0.12);
      final path = Path()
        ..moveTo(size.width * 0.55, y)
        ..cubicTo(
          size.width * 0.7,
          y - 18,
          size.width * 0.82,
          y + 18,
          size.width * 1.08,
          y - 3,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _paintFlowingWater(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(
      size.width * 0.58,
      0,
      size.width * 0.42,
      size.height,
    );
    canvas.save();
    canvas.clipRect(bounds);
    for (var index = 0; index < 3; index++) {
      final path = Path()
        ..moveTo(size.width * (0.7 + index * 0.12), -12)
        ..cubicTo(
          size.width * 0.56,
          size.height * 0.34,
          size.width * 1.05,
          size.height * 0.54,
          size.width * (0.76 + index * 0.1),
          size.height + 12,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: index == 0 ? 0.16 : 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 12 : 4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _paintStackedWaves(Canvas canvas, Size size) {
    final colors = [
      Colors.white.withValues(alpha: 0.08),
      Colors.white.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.16),
    ];
    for (var index = 0; index < colors.length; index++) {
      final y = size.height * (0.68 + index * 0.1);
      final path = Path()
        ..moveTo(size.width * 0.38, y)
        ..cubicTo(
          size.width * 0.58,
          y - 26,
          size.width * 0.73,
          y + 20,
          size.width,
          y - 5,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.38, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[index]);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterOrnamentPainter oldDelegate) =>
      ornament != oldDelegate.ornament;
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
