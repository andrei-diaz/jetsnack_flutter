import 'package:flutter/material.dart';

class JetsnackColors {
  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color iconPrimary;
  final Color iconInteractive;
  final Color iconInteractiveInactive;
  const JetsnackColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.iconPrimary,
    required this.iconInteractive,
    required this.iconInteractiveInactive,
  });

  static const light = JetsnackColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF5E56F0), // Jetsnack accent purple
    onPrimary: Color(0xFFFFFFFF),
    iconPrimary: Color(0xFF5E56F0), // bottom bar background
    iconInteractive: Color(0xFFFFFFFF),
    iconInteractiveInactive: Color(0x80FFFFFF),
  );
}

class JetsnackTheme extends InheritedWidget {
  const JetsnackTheme({super.key, required this.colors, required super.child});
  final JetsnackColors colors;

  static JetsnackColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JetsnackTheme>()!.colors;

  @override
  bool updateShouldNotify(covariant JetsnackTheme oldWidget) => colors != oldWidget.colors;
}