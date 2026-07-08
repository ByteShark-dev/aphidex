import 'package:flutter/widgets.dart';

enum AppSurfaceSize { compact, medium, expanded, wide }

class AppBreakpoints {
  static const double compactMaxWidth = 599;
  static const double mediumMaxWidth = 839;
  static const double expandedMaxWidth = 1199;
  static const double tabletShortestSide = 600;

  static AppSurfaceSize surfaceForWidth(double width) {
    if (width <= compactMaxWidth) {
      return AppSurfaceSize.compact;
    }
    if (width <= mediumMaxWidth) {
      return AppSurfaceSize.medium;
    }
    if (width <= expandedMaxWidth) {
      return AppSurfaceSize.expanded;
    }
    return AppSurfaceSize.wide;
  }

  static bool isMasterDetail(double width) => surfaceForWidth(width).index >= 3;

  static bool usesRail(double width) => width >= 1320;

  static bool isTabletLike(Size size) =>
      size.shortestSide >= tabletShortestSide;

  static bool shouldShowCreatureCards(Size size) =>
      isTabletLike(size) || isMasterDetail(size.width);
}

extension AppSurfaceSizeX on AppSurfaceSize {
  bool get isCompact => this == AppSurfaceSize.compact;

  bool get isMedium => this == AppSurfaceSize.medium;

  bool get isExpanded => this == AppSurfaceSize.expanded;

  bool get isWide => this == AppSurfaceSize.wide;

  EdgeInsets get pagePadding => switch (this) {
    AppSurfaceSize.compact => const EdgeInsets.all(12),
    AppSurfaceSize.medium => const EdgeInsets.all(16),
    AppSurfaceSize.expanded => const EdgeInsets.all(18),
    AppSurfaceSize.wide => const EdgeInsets.all(20),
  };
}
