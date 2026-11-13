import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class DynamicWaterHeader extends StatefulWidget {
  const DynamicWaterHeader({
    super.key,
    required this.height,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.animated = false,
    this.backgroundImageAsset,
  });

  final double height;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool animated;
  final String? backgroundImageAsset;

  @override
  State<DynamicWaterHeader> createState() => _DynamicWaterHeaderState();
}

class _DynamicWaterHeaderState extends State<DynamicWaterHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    );
    if (widget.animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant DynamicWaterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      widget.animated ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaterWaveClipper(),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: widget.backgroundImageAsset == null
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
              )
            : BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(widget.backgroundImageAsset!),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
        child: Stack(
          children: [
            if (widget.backgroundImageAsset != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.48),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.animated)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                height: widget.height * 0.58,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _AnimatedWaterPainter(_controller.value),
                  ),
                ),
              ),
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
            Padding(padding: widget.padding, child: widget.child),
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
              fontWeight: FontWeight.w400,
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

class _AnimatedWaterPainter extends CustomPainter {
  const _AnimatedWaterPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWave(
      canvas,
      size,
      baseHeight: size.height * 0.58,
      amplitude: size.height * 0.105,
      phase: progress * math.pi * 2,
      color: Colors.white.withValues(alpha: 0.16),
      widthScale: 1.0,
    );
    _paintWave(
      canvas,
      size,
      baseHeight: size.height * 0.74,
      amplitude: size.height * 0.085,
      phase: progress * math.pi * 2 + math.pi * 0.72,
      color: Colors.white.withValues(alpha: 0.24),
      widthScale: 1.28,
    );
    _paintWave(
      canvas,
      size,
      baseHeight: size.height * 0.86,
      amplitude: size.height * 0.055,
      phase: progress * math.pi * 2 + math.pi * 1.45,
      color: const Color(0xA8EAFBFF),
      widthScale: 0.82,
    );
  }

  void _paintWave(
    Canvas canvas,
    Size size, {
    required double baseHeight,
    required double amplitude,
    required double phase,
    required Color color,
    required double widthScale,
  }) {
    final path = Path()..moveTo(0, baseHeight);
    for (var x = 0.0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      final y = baseHeight +
          math.sin(normalizedX * math.pi * 2 * widthScale + phase) *
              amplitude +
          math.sin(normalizedX * math.pi * 4 * widthScale - phase * 0.35) *
              amplitude *
              0.18;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AnimatedWaterPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
