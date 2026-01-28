import 'package:flutter/material.dart';

class ScrollableChartWrapper extends StatelessWidget {
  final Widget child;
  final int itemCount;
  final double minItemWidth;
  final double height;

  const ScrollableChartWrapper({
    super.key,
    required this.child,
    required this.itemCount,
    this.minItemWidth = 40.0,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = itemCount * minItemWidth;
        final shouldScroll = totalWidth > constraints.maxWidth;

        if (!shouldScroll) {
          return SizedBox(height: height, width: double.infinity, child: child);
        }

        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: SizedBox(
              width: totalWidth < constraints.maxWidth
                  ? constraints.maxWidth
                  : totalWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
