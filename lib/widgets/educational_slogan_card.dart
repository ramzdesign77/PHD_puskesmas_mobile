import 'package:flutter/material.dart';
import 'package:wave/wave.dart';

import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class EducationalSloganCard extends StatelessWidget {
  const EducationalSloganCard({
    super.key,
    this.slogan = 'Lingkungan Bersih, Sumber Air Sehat, Keluarga Kuat',
  });

  final String slogan;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('education_slogan_card'),
      width: double.infinity,
      height: 136,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          WaveWidget(
            config: CustomConfig(
              colors: const [
                Color(0x6606B6D4),
                Color(0x4D06B6D4),
                Color(0x3306B6D4),
              ],
              durations: const [12000, 9000, 7000],
              heightPercentages: const [0.42, 0.54, 0.66],
            ),
            size: Size.infinite,
            waveAmplitude: 16,
            waveFrequency: 1.4,
          ),
          DecoratedBox(
            key: const Key('education_slogan_card_overlay'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x55002B4A),
                  Color(0x22002B4A),
                  Color(0x55002B4A),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                slogan,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.headlineFontFamily,
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
