import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// A responsive wrapper widget that provides different layouts for mobile and desktop
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileWidget(),
///   desktop: DesktopWidget(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveUtils.isMobile(context)) {
          return mobile;
        } else if (ResponsiveUtils.isTablet(context)) {
          return tablet ?? desktop ?? mobile;
        } else {
          return desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}

/// A responsive card widget that adapts its padding and margins based on screen size
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.color,
    this.margin,
    this.padding,
    this.elevation,
    this.borderRadius,
    this.border,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveMargin = margin ?? ResponsiveUtils.getCardMargin(context);
    final responsivePadding =
        padding ?? ResponsiveUtils.getCardPadding(context);
    final responsiveElevation =
        elevation ?? ResponsiveUtils.getElevation(context);
    final responsiveBorderRadius =
        borderRadius ??
        BorderRadius.circular(ResponsiveUtils.getBorderRadius(context));

    Widget cardContent = Container(
      padding: responsivePadding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: responsiveBorderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: responsiveElevation * 3,
            offset: Offset(0, responsiveElevation),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: responsiveBorderRadius,
        child: cardContent,
      );
    }

    return Container(margin: responsiveMargin, child: cardContent);
  }
}

/// A responsive row/column widget that switches between Row and Column based on screen size
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.forceColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final shouldStack =
        forceColumn || ResponsiveUtils.shouldStackVertically(context);

    if (shouldStack) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    }
  }
}

/// A responsive grid widget that adjusts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getGridColumns(
      context,
      mobileColumns: mobileColumns,
      tabletColumns: tabletColumns,
      desktopColumns: desktopColumns,
    );

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// A responsive padding widget that adjusts padding based on screen size
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? horizontal;
  final double? vertical;
  final double? all;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.horizontal,
    this.vertical,
    this.all,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveUtils.responsivePadding(
        context,
        horizontal: horizontal,
        vertical: vertical,
        all: all,
      ),
      child: child,
    );
  }
}

/// A responsive text widget that adjusts font size based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.baseFontSize = 16,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: ResponsiveUtils.responsiveFontSize(context, baseFontSize),
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// A responsive container that limits max width on large screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Decoration? decoration;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveUtils.getMaxContentWidth(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        padding: padding,
        margin: margin,
        color: decoration == null ? color : null,
        decoration: decoration,
        child: child,
      ),
    );
  }
}
