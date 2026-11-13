import 'package:flutter/material.dart';

import '../widgets/fluid_bottom_nav.dart';

class MainLayoutScreen extends StatelessWidget {
  const MainLayoutScreen({
    super.key,
    required this.pages,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.bodySafeArea = true,
  }) : assert(pages.length == destinations.length),
       assert(selectedIndex >= 0),
       assert(selectedIndex < pages.length);

  final List<Widget> pages;
  final List<FluidNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color backgroundColor;
  final bool bodySafeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: bodySafeArea
          ? SafeArea(
              bottom: false,
              child: LiquidRevealPageTransition(
                transitionKey: selectedIndex,
                child: IndexedStack(index: selectedIndex, children: pages),
              ),
            )
          : LiquidRevealPageTransition(
              transitionKey: selectedIndex,
              child: IndexedStack(index: selectedIndex, children: pages),
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          10 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FluidBottomNav(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
        ),
      ),
    );
  }
}

class LiquidRevealPageTransition extends StatefulWidget {
  const LiquidRevealPageTransition({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  State<LiquidRevealPageTransition> createState() =>
      _LiquidRevealPageTransitionState();
}

class _LiquidRevealPageTransitionState extends State<LiquidRevealPageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidRevealPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionKey != oldWidget.transitionKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(_controller.value);
          return ClipPath(
            clipper: _LiquidRevealClipper(progress),
            child: child,
          );
        },
      ),
    );
  }
}

class _LiquidRevealClipper extends CustomClipper<Path> {
  const _LiquidRevealClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    if (progress >= 1) return Path()..addRect(Offset.zero & size);

    final origin = Offset(size.width / 2, size.height * 0.9);
    final maxRadius = size.longestSide * 1.5;
    final radius = maxRadius * progress;
    return Path()..addOval(Rect.fromCircle(center: origin, radius: radius));
  }

  @override
  bool shouldReclip(covariant _LiquidRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
