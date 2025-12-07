import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Utility class for responsive design helpers
///
/// Provides methods to detect device type, calculate responsive sizes,
/// and apply adaptive layouts throughout the app.
class ResponsiveUtils {
  /// Check if the current screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  /// Check if the current screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.desktop;
  }

  /// Check if the current screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(
    BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    final mobile = isMobile(context);

    if (all != null) {
      return EdgeInsets.all(mobile ? all * 0.75 : all);
    }

    return EdgeInsets.symmetric(
      horizontal: horizontal != null
          ? (mobile ? horizontal * 0.75 : horizontal)
          : 0,
      vertical: vertical != null ? (mobile ? vertical * 0.75 : vertical) : 0,
    );
  }

  /// Get responsive margin based on screen size
  static EdgeInsets responsiveMargin(
    BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    final mobile = isMobile(context);

    if (all != null) {
      return EdgeInsets.all(mobile ? all * 0.75 : all);
    }

    return EdgeInsets.symmetric(
      horizontal: horizontal != null
          ? (mobile ? horizontal * 0.75 : horizontal)
          : 0,
      vertical: vertical != null ? (mobile ? vertical * 0.75 : vertical) : 0,
    );
  }

  /// Get responsive font size
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final mobile = isMobile(context);
    return mobile ? baseSize * 0.9 : baseSize;
  }

  /// Get responsive icon size
  static double responsiveIconSize(BuildContext context, double baseSize) {
    final mobile = isMobile(context);
    return mobile ? baseSize * 0.85 : baseSize;
  }

  /// Get number of columns for grid based on screen size
  static int getGridColumns(
    BuildContext context, {
    int mobileColumns = 1,
    int tabletColumns = 2,
    int desktopColumns = 3,
  }) {
    if (isMobile(context)) return mobileColumns;
    if (isTablet(context)) return tabletColumns;
    return desktopColumns;
  }

  /// Get responsive card margin
  static EdgeInsets getCardMargin(BuildContext context) {
    final mobile = isMobile(context);
    return EdgeInsets.symmetric(
      horizontal: mobile ? 8 : 16,
      vertical: mobile ? 6 : 8,
    );
  }

  /// Get responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final mobile = isMobile(context);
    return EdgeInsets.all(mobile ? 12 : 16);
  }

  /// Get responsive AppBar height
  static double getAppBarHeight(BuildContext context) {
    final mobile = isMobile(context);
    return mobile ? 56 : 64;
  }

  /// Get responsive AppBar bottom section height
  static double getAppBarBottomHeight(
    BuildContext context, {
    double baseHeight = 120,
  }) {
    final mobile = isMobile(context);
    return mobile ? baseHeight * 0.85 : baseHeight;
  }

  /// Calculate value based on screen width percentage
  static double widthPercentage(BuildContext context, double percentage) {
    return screenWidth(context) * (percentage / 100);
  }

  /// Calculate value based on screen height percentage
  static double heightPercentage(BuildContext context, double percentage) {
    return screenHeight(context) * (percentage / 100);
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, double baseSpacing) {
    final mobile = isMobile(context);
    return mobile ? baseSpacing * 0.75 : baseSpacing;
  }

  /// Determine if content should stack vertically (for mobile)
  static bool shouldStackVertically(BuildContext context) {
    return isMobile(context);
  }

  /// Get responsive border radius
  static double getBorderRadius(
    BuildContext context, {
    double baseRadius = 12,
  }) {
    final mobile = isMobile(context);
    return mobile ? baseRadius * 0.85 : baseRadius;
  }

  /// Get responsive elevation
  static double getElevation(BuildContext context, {double baseElevation = 2}) {
    final mobile = isMobile(context);
    return mobile ? baseElevation * 0.75 : baseElevation;
  }

  /// Get device type as string (for debugging)
  static String getDeviceType(BuildContext context) {
    if (isMobile(context)) return 'Mobile';
    if (isTablet(context)) return 'Tablet';
    return 'Desktop';
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final width = screenWidth(context);
    if (isMobile(context)) {
      return width * 0.9; // 90% of screen width on mobile
    } else if (isTablet(context)) {
      return width * 0.7; // 70% on tablet
    } else {
      return 600; // Fixed width on desktop
    }
  }

  /// Get maximum content width for readability
  static double getMaxContentWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width > 1200) {
      return 1200; // Max width for very large screens
    }
    return width;
  }
}
