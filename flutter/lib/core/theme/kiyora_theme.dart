import 'package:material_ui/material_ui.dart';

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
        primary: dark ? const Color(0xffff8298) : const Color(0xffbb1238),
        onPrimary: dark ? const Color(0xff2b0010) : Colors.white,
        surface: tokens.panel,
        onSurface: dark ? const Color(0xfff5f5f5) : const Color(0xff181818),
        onSurfaceVariant: dark
            ? const Color(0xffc9c9c9)
            : const Color(0xff505050),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      floatingLabelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xffbb1238),
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
    visualDensity: VisualDensity.standard,
  );
}
