import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class StbmCampaignView extends StatelessWidget {
  const StbmCampaignView({super.key});

  static const _pillars = [
    (
      title: 'Stop Buang Air Besar Sembarangan',
      description:
          'Gunakan jamban sehat dan pastikan tinja tidak mencemari lingkungan maupun sumber air.',
      icon: Icons.wc_outlined,
    ),
    (
      title: 'Cuci Tangan Pakai Sabun',
      description:
          'Biasakan mencuci tangan dengan sabun dan air mengalir pada waktu-waktu penting.',
      icon: Icons.wash_outlined,
    ),
    (
      title: 'Pengelolaan Air Minum dan Makanan Rumah Tangga',
      description:
          'Jaga air minum tetap aman dan kelola makanan secara bersih, tertutup, serta higienis.',
      icon: Icons.water_drop_outlined,
    ),
    (
      title: 'Pengamanan Sampah Rumah Tangga',
      description:
          'Pilah dan kelola sampah dengan benar agar tidak menjadi sumber penyakit dan pencemaran.',
      icon: Icons.delete_outline_rounded,
    ),
    (
      title: 'Pengamanan Limbah Cair Rumah Tangga',
      description:
          'Salurkan dan kelola air limbah rumah tangga agar tidak menggenang atau mencemari lingkungan.',
      icon: Icons.recycling_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CampaignHeader(onBack: () => Navigator.pop(context)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      Text(
                        'Mulai dari kebiasaan sehari-hari',
                        style: TextStyle(
                          fontFamily: AppTheme.headlineFontFamily,
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Sanitasi Total Berbasis Masyarakat (STBM) mengajak setiap keluarga dan komunitas membangun perilaku hidup bersih dan sehat.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var index = 0; index < _pillars.length; index++) ...[
                        _PillarCard(
                          number: index + 1,
                          title: _pillars[index].title,
                          description: _pillars[index].description,
                          icon: _pillars[index].icon,
                        ),
                        if (index < _pillars.length - 1)
                          const SizedBox(height: 12),
                      ],
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

class _CampaignHeader extends StatelessWidget {
  const _CampaignHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: 8,
            child: Icon(
              Icons.water_drop_rounded,
              color: Colors.white.withValues(alpha: 0.13),
              size: 130,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Kembali',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
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
                const SizedBox(height: 12),
                const Text(
                  '5 Pilar STBM',
                  style: TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bersama wujudkan lingkungan sehat dan bebas penyakit.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.45,
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

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PILAR $number',
                  style: TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
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
