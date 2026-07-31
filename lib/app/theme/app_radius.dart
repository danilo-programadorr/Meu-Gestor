import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double smallValue = 8;
  static const double mediumValue = 14;
  static const double largeValue = 22;
  static const double heroValue = 28;
  static const double roundValue = 999;

  static const BorderRadius small = BorderRadius.all(
    Radius.circular(smallValue),
  );
  static const BorderRadius medium = BorderRadius.all(
    Radius.circular(mediumValue),
  );
  static const BorderRadius large = BorderRadius.all(
    Radius.circular(largeValue),
  );
  static const BorderRadius hero = BorderRadius.all(Radius.circular(heroValue));
}
