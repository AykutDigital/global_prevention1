import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Responsive breakpoint helper widget.
/// Builds different layouts based on screen width.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppTheme.mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint &&
      MediaQuery.sizeOf(context).width < AppTheme.tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppTheme.tabletBreakpoint;

  /// Returns the number of grid columns based on width
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppTheme.tabletBreakpoint) {
      return desktop;
    }
    if (width >= AppTheme.mobileBreakpoint && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}
