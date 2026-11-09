import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

const _fluidAnimationDuration = Duration(milliseconds: 420);
const _fluidNavHeight = 64.0;
const _fluidNavLabeledHeight = 82.0;
const _fluidNavSelectedButtonSize = 50.0;
const _fluidNavSelectedButtonOffset = 18.0;
const _fluidNavNotchMargin = 8.0;
const _fluidNavCornerRadius = 32.0;
const _fluidNavLabeledButtonSize = 40.0;
const _fluidNavLabeledButtonOffset = 13.0;
const _fluidNavLabeledBarTop = 28.0;
const _fluidNavLabeledCornerRadius = 20.0;

class FluidNavDestination {
  const FluidNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class FluidBottomNav extends StatefulWidget {
  const FluidBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showLabels = false,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0),
       assert(selectedIndex < destinations.length);

  final List<FluidNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showLabels;

  @override
  State<FluidBottomNav> createState() => _FluidBottomNavState();
}

class _FluidBottomNavState extends State<FluidBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionController;
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _selectionController = AnimationController(
      vsync: this,
      duration: _fluidAnimationDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant FluidBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / widget.destinations.length;
        final navHeight = widget.showLabels
            ? _fluidNavLabeledHeight
            : _fluidNavHeight;
        return AnimatedBuilder(
          animation: _selectionController,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(
              _selectionController.value,
            );
            final activePosition =
                lerpDouble(
                      _previousIndex.toDouble(),
                      widget.selectedIndex.toDouble(),
                      progress,
                    )! *
                    itemWidth +
                itemWidth / 2;
            return Container(
              height: navHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_fluidNavCornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 26,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  ClipPath(
                    clipBehavior: Clip.antiAlias,
                    clipper: _FluidNavClipper(
                      activePosition,
                      progress,
                      showLabels: widget.showLabels,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.76),
                                  const Color(0xFFDDF4FC)
                                      .withValues(alpha: 0.70),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _FluidNavBorderPainter(
                            activePosition,
                            progress,
                            showLabels: widget.showLabels,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < widget.destinations.length;
                        index++
                      )
                        Expanded(
                          child: _FluidNavButton(
                            destination: widget.destinations[index],
                            selected: index == widget.selectedIndex,
                            showLabel: widget.showLabels,
                            onTap: () => widget.onDestinationSelected(index),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FluidNavButton extends StatefulWidget {
  const _FluidNavButton({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final FluidNavDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_FluidNavButton> createState() => _FluidNavButtonState();
}

class _FluidNavButtonState extends State<_FluidNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: _fluidAnimationDuration,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _FluidNavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _bounceController.forward(from: 0);
      } else {
        _bounceController.animateTo(
          0,
          duration: _fluidAnimationDuration,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: widget.showLabel ? _fluidNavLabeledHeight : _fluidNavHeight,
          child: AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final bounce = Curves.easeOutCubic.transform(
                _bounceController.value,
              );
              final selected = widget.selected;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment(0, 0),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        selected
                            ? -(widget.showLabel
                                      ? _fluidNavLabeledButtonOffset
                                      : _fluidNavSelectedButtonOffset) *
                                  bounce
                            : 0,
                      ),
                      child: Transform.scale(
                        scale: selected ? 0.92 + 0.08 * bounce : 1,
                        child: selected
                            ? Container(
                                key: Key(
                                  'fluid_nav_drop_${widget.destination.label}',
                                ),
                                width: widget.showLabel
                                    ? _fluidNavLabeledButtonSize
                                    : _fluidNavSelectedButtonSize,
                                height: widget.showLabel
                                    ? _fluidNavLabeledButtonSize
                                    : _fluidNavSelectedButtonSize,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Color(0xFFE0F2FE)],
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x330284C7),
                                      blurRadius: 12,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.destination.selectedIcon ??
                                      widget.destination.icon,
                                  size: widget.showLabel ? 30 : 26,
                                  color: AppColors.primary,
                                ),
                              )
                            : SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  widget.destination.icon,
                                  size: 26,
                                  color: AppColors.muted,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (widget.showLabel)
                    Positioned(
                      left: 1,
                      right: 1,
                      bottom: 5,
                      child: Text(
                        widget.destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.muted,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FluidNavClipper extends CustomClipper<Path> {
  const _FluidNavClipper(
    this.notchCenter,
    this.selectionProgress, {
    this.showLabels = false,
  });

  final double notchCenter;
  final double selectionProgress;
  final bool showLabels;

  @override
  Path getClip(Size size) {
    final progress = selectionProgress.clamp(0.0, 1.0);
    final buttonScale = 0.92 + 0.08 * progress;
    final buttonRadius =
        (showLabels
            ? _fluidNavLabeledButtonSize
            : _fluidNavSelectedButtonSize) *
        buttonScale /
        2;
    final barTop = showLabels ? _fluidNavLabeledBarTop : 0.0;
    final buttonCenter = showLabels
        ? Offset(notchCenter, barTop)
        : Offset(
            notchCenter,
            size.height / 2 - _fluidNavSelectedButtonOffset * progress,
          );
    final notchRadius = showLabels
        ? buttonRadius + 2
        : buttonRadius + _fluidNavNotchMargin;
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, size.width, size.height - barTop),
          Radius.circular(
            showLabels ? _fluidNavLabeledCornerRadius : _fluidNavCornerRadius,
          ),
        ),
      );
    final notch = Path()
      ..addOval(Rect.fromCircle(center: buttonCenter, radius: notchRadius));
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  bool shouldReclip(covariant _FluidNavClipper oldClipper) =>
      oldClipper.notchCenter != notchCenter ||
      oldClipper.selectionProgress != selectionProgress ||
      oldClipper.showLabels != showLabels;
}

class _FluidNavBorderPainter extends CustomPainter {
  const _FluidNavBorderPainter(
    this.notchCenter,
    this.selectionProgress, {
    this.showLabels = false,
  });

  final double notchCenter;
  final double selectionProgress;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _FluidNavClipper(
      notchCenter,
      selectionProgress,
      showLabels: showLabels,
    ).getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FluidNavBorderPainter oldDelegate) =>
      oldDelegate.notchCenter != notchCenter ||
      oldDelegate.selectionProgress != selectionProgress ||
      oldDelegate.showLabels != showLabels;
}
