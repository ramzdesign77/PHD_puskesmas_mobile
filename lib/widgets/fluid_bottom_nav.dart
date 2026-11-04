import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

const _fluidAnimationDuration = Duration(milliseconds: 420);
const _fluidNavHeight = 64.0;
const _fluidNavSelectedButtonSize = 50.0;
const _fluidNavSelectedButtonOffset = 18.0;
const _fluidNavNotchMargin = 8.0;
const _fluidNavCornerRadius = 32.0;

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
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0),
       assert(selectedIndex < destinations.length);

  final List<FluidNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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
              height: _fluidNavHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_fluidNavCornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.19),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.09),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  ClipPath(
                    clipBehavior: Clip.antiAlias,
                    clipper: _FluidNavClipper(activePosition, progress),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _FluidNavBorderPainter(
                            activePosition,
                            progress,
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
    required this.onTap,
  });

  final FluidNavDestination destination;
  final bool selected;
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
          height: _fluidNavHeight,
          child: AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final bounce = Curves.easeOutCubic.transform(
                _bounceController.value,
              );
              final selected = widget.selected;
              return Center(
                child: Transform.translate(
                  offset: Offset(
                    0,
                    selected ? -_fluidNavSelectedButtonOffset * bounce : 0,
                  ),
                  child: Transform.scale(
                    scale: selected ? 0.92 + 0.08 * bounce : 1,
                    child: Container(
                      width: selected ? _fluidNavSelectedButtonSize : 44,
                      height: selected ? _fluidNavSelectedButtonSize : 44,
                      alignment: Alignment.center,
                      decoration: selected
                          ? const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x390284C7),
                                  blurRadius: 12,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        selected
                            ? widget.destination.selectedIcon ??
                                  widget.destination.icon
                            : widget.destination.icon,
                        size: 26,
                        color: selected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FluidNavClipper extends CustomClipper<Path> {
  const _FluidNavClipper(this.notchCenter, this.selectionProgress);

  final double notchCenter;
  final double selectionProgress;

  @override
  Path getClip(Size size) {
    final progress = selectionProgress.clamp(0.0, 1.0);
    final buttonScale = 0.92 + 0.08 * progress;
    final buttonRadius = _fluidNavSelectedButtonSize * buttonScale / 2;
    final buttonCenter = Offset(
      notchCenter,
      size.height / 2 - _fluidNavSelectedButtonOffset * progress,
    );
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_fluidNavCornerRadius),
        ),
      );
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: buttonCenter,
          radius: buttonRadius + _fluidNavNotchMargin,
        ),
      );
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  bool shouldReclip(covariant _FluidNavClipper oldClipper) =>
      oldClipper.notchCenter != notchCenter ||
      oldClipper.selectionProgress != selectionProgress;
}

class _FluidNavBorderPainter extends CustomPainter {
  const _FluidNavBorderPainter(this.notchCenter, this.selectionProgress);

  final double notchCenter;
  final double selectionProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _FluidNavClipper(notchCenter, selectionProgress).getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FluidNavBorderPainter oldDelegate) =>
      oldDelegate.notchCenter != notchCenter ||
      oldDelegate.selectionProgress != selectionProgress;
}
