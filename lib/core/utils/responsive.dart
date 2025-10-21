import 'package:flutter/material.dart';

class Responsive {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static double getResponsiveValue({
    required BuildContext context,
    required double small,
    double? medium,
    double? large,
  }) {
    if (isSmallScreen(context)) {
      return small;
    } else if (isMediumScreen(context)) {
      return medium ?? small;
    } else {
      return large ?? medium ?? small;
    }
  }
}
