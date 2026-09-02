import 'package:flutter/material.dart';

class AppNavigator {
  static push(context, screen, animationType) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return animationType(animation, child);
        },
      ),
    );
  }

  static pushR(context, screen, animationType) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return animationType(animation, child);
        },
      ),
    );
  }

  static pop(context) {
    Navigator.pop(context);
  }
}

class NavigatorAnimation {
  static slideAnimation(animation, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: const Offset(0, 0),
    ).animate(animation),
    child: child,
  );
  static fadeAnimation(animation, child) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
    child: child,
  );
  static scaleAnimation(animation, child) => ScaleTransition(
    alignment: const Alignment(0.28, 0.9),
    scale: Tween<double>(begin: 0.1, end: 1.0).animate(animation),
    child: child,
  );
}
