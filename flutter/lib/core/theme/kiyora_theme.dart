import 'package:flutter/material.dart';

@immutable
class KiyoraColors extends ThemeExtension<KiyoraColors> {
  const KiyoraColors({
    required this.canvas,
    required this.panel,
    required this.raised,
  });
  static const accent = Color(0xffff2448);
  final Color canvas;
  final Color panel;
  final Color raised;

  @override
  KiyoraColors copyWith({Color? canvas, Color? panel, Color? raised}) =>
      KiyoraColors(
        canvas: canvas ?? this.canvas,
        panel: panel ?? this.panel,
        raised: raised ?? this.raised,
      );
  @override
  KiyoraColors lerp(KiyoraColors? other, double t) => other == null
      ? this
      : KiyoraColors(
          canvas: Color.lerp(canvas, other.canvas, t)!,
          panel: Color.lerp(panel, other.panel, t)!,
          raised: Color.lerp(raised, other.raised, t)!,
        );
}

ThemeData kiyoraTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final tokens = KiyoraColors(
    canvas: dark ? const Color(0xff080808) : const Color(0xffeaeaea),
    panel: dark ? const Color(0xff121212) : const Color(0xfffafafa),
    raised: dark ? const Color(0xff242424) : const Color(0xffe3e3e3),
  );
  final scheme =
      ColorScheme.fromSeed(
        seedColor: KiyoraColors.accent,
        brightness: brightness,
      ).copyWith(
        primary: KiyoraColors.accent,
        onPrimary: Colors.white,
        surface: tokens.panel,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.canvas,
    extensions: [tokens],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(backgroundColor: tokens.canvas, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.canvas,
      indicatorColor: tokens.raised,
      height: 72,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
    visualDensity: VisualDensity.standard,
  );
}
