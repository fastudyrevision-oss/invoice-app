/// Responsive breakpoint constants for the Invoice App
///
/// These breakpoints define the screen width thresholds for different device types:
/// - Mobile: < 600px (phones in portrait)
/// - Tablet: 600-900px (tablets and large phones in landscape)
/// - Desktop: > 900px (tablets in landscape and desktop screens)
class ResponsiveBreakpoints {
  // Screen width breakpoints
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  // Responsive spacing scales
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // Responsive padding scales
  static double paddingSmall(bool isMobile) => isMobile ? 8 : 12;
  static double paddingMedium(bool isMobile) => isMobile ? 12 : 16;
  static double paddingLarge(bool isMobile) => isMobile ? 16 : 24;

  // Responsive margin scales
  static double marginSmall(bool isMobile) => isMobile ? 8 : 12;
  static double marginMedium(bool isMobile) => isMobile ? 12 : 16;
  static double marginLarge(bool isMobile) => isMobile ? 16 : 24;

  // Responsive font sizes
  static double fontSizeSmall(bool isMobile) => isMobile ? 12 : 13;
  static double fontSizeMedium(bool isMobile) => isMobile ? 14 : 16;
  static double fontSizeLarge(bool isMobile) => isMobile ? 16 : 18;
  static double fontSizeXLarge(bool isMobile) => isMobile ? 18 : 20;
  static double fontSizeTitle(bool isMobile) => isMobile ? 20 : 24;

  // AppBar heights
  static double appBarHeight(bool isMobile) => isMobile ? 56 : 64;
  static double appBarBottomHeight(bool isMobile) => isMobile ? 100 : 120;

  // Card dimensions
  static double cardBorderRadius = 12;
  static double cardElevation = 2;

  // Touch target minimum size (Material Design guideline)
  static const double minTouchTarget = 48;

  // Icon sizes
  static double iconSizeSmall(bool isMobile) => isMobile ? 16 : 18;
  static double iconSizeMedium(bool isMobile) => isMobile ? 20 : 24;
  static double iconSizeLarge(bool isMobile) => isMobile ? 24 : 28;
}
