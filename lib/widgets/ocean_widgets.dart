import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class DynamicWaterHeader extends StatelessWidget {
  const DynamicWaterHeader({
    super.key,
    required this.height,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double height;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaterWaveClipper(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -54,
              right: -42,
              child: _Bubble(size: 190, opacity: 0.1),
            ),
            Positioned(
              top: 96,
              left: -34,
              child: _Bubble(size: 112, opacity: 0.09),
            ),
            Positioned(
              right: 68,
              bottom: 42,
              child: Icon(
                Icons.water_drop_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class WaterLoadingIndicator extends StatefulWidget {
  const WaterLoadingIndicator({super.key, this.size = 46});

  final double size;

  @override
  State<WaterLoadingIndicator> createState() => _WaterLoadingIndicatorState();
}

class _WaterLoadingIndicatorState extends State<WaterLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.9 + math.sin(_controller.value * math.pi * 2) * 0.1;
        return Transform.scale(scale: pulse, child: child);
      },
      child: Icon(
        Icons.water_drop_rounded,
        size: widget.size,
        color: AppColors.primary,
      ),
    );
  }
}

class WaterEmptyState extends StatelessWidget {
  const WaterEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.water_drop_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.softRed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity * 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

class _WaterWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.75,
        size.width * 0.34,
        size.height * 0.98,
        size.width * 0.56,
        size.height * 0.9,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.82,
        size.width * 0.88,
        size.height * 0.9,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaterWaveClipper oldClipper) => false;
}
