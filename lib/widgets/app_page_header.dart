import 'package:flutter/material.dart';

import 'ocean_widgets.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  static const height = 265.0;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DynamicWaterHeader(height: height, padding: padding, child: child);
  }
}
