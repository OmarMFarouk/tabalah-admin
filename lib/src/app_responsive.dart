import 'package:flutter/material.dart';

extension DevicesChecker on BuildContext {
  bool get isSmall => MediaQuery.sizeOf(this).width < 1100;
  bool get isTiny => MediaQuery.sizeOf(this).width < 800;
}
