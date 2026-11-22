import 'package:material_ui/material_ui.dart';

/// Visual theme in the style of the PF dashboard ("liquid glass" over an aurora
/// backdrop). Each variant changes the accent and the aurora light colours.
class AppTheme {
  const AppTheme(this.id, this.name, this.accent, this.aurora);
  final String id;
  final String name;
  final Color accent;

  /// Five lights shining through the glass: cyan, violet, magenta, blue, mint
  /// in the default variant.
  final List<Color> aurora;

  List<Color> get gradient => [aurora[0], aurora[1]];
}

Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

final appThemes = <AppTheme>[
  AppTheme('aurora', 'Аврора', _hsl(200, 92, 56), [
    _hsl(186, 100, 50), _hsl(262, 90, 62), _hsl(322, 85, 60), //
    _hsl(214, 95, 58), _hsl(158, 80, 46),
  ]),
  AppTheme('lagoon', 'Лагуна', _hsl(176, 90, 45), [
    _hsl(176, 100, 45), _hsl(214, 95, 58), _hsl(240, 80, 62), //
    _hsl(196, 95, 52), _hsl(150, 80, 46),
  ]),
  AppTheme('nebula', 'Туманність', _hsl(268, 88, 66), [
    _hsl(268, 90, 64), _hsl(322, 85, 60), _hsl(222, 90, 60), //
    _hsl(290, 80, 58), _hsl(200, 90, 56),
  ]),
  AppTheme('sunset', 'Захід', _hsl(24, 95, 58), [
    _hsl(24, 100, 58), _hsl(340, 85, 60), _hsl(280, 75, 58), //
    _hsl(45, 95, 55), _hsl(200, 80, 50),
  ]),
  AppTheme('forest', 'Ліс', _hsl(152, 70, 46), [
    _hsl(152, 80, 44), _hsl(186, 90, 46), _hsl(90, 60, 50), //
    _hsl(214, 80, 56), _hsl(60, 80, 50),
  ]),
];

AppTheme themeById(String id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.gradient,
    required this.aurora,
    required this.income,
    required this.expense,
    required this.glassFill,
    required this.glassRim,
    required this.base,
  });
  final List<Color> gradient;
  final List<Color> aurora;
  final Color income;
  final Color expense;
  final List<Color> glassFill;
  final List<Color> glassRim;
  final List<Color> base; // backdrop base gradient

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith() => this;

  static List<Color> _lerpList(List<Color> a, List<Color> b, double t) => [
        for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
      ];

  @override
  AppPalette lerp(AppPalette? o, double t) {
    if (o == null) return this;
    return AppPalette(
      gradient: _lerpList(gradient, o.gradient, t),
      aurora: _lerpList(aurora, o.aurora, t),
      income: Color.lerp(income, o.income, t)!,
      expense: Color.lerp(expense, o.expense, t)!,
      glassFill: _lerpList(glassFill, o.glassFill, t),
      glassRim: _lerpList(glassRim, o.glassRim, t),
      base: _lerpList(base, o.base, t),
    );
  }
}

ThemeData buildTheme(AppTheme t, Brightness b) {
  final dark = b == Brightness.dark;
  final text = dark ? const Color(0xF5FFFFFF) : _hsl(232, 30, 12);
  final soft = dark ? const Color(0xA8EBF0FF) : _hsl(232, 14, 38);
  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: b,
  ).copyWith(
    primary: t.accent,
    onSurface: text,
    onSurfaceVariant: soft,
    surface: dark ? _hsl(232, 30, 9) : _hsl(220, 50, 97),
    surfaceContainerLow: dark ? const Color(0x14FFFFFF) : const Color(0x80FFFFFF),
    surfaceContainerHighest: dark ? const Color(0x24FFFFFF) : const Color(0xB3FFFFFF),
  );
  final palette = AppPalette(
    gradient: t.gradient,
    aurora: t.aurora,
    income: dark ? _hsl(150, 70, 60) : _hsl(150, 60, 36),
    expense: dark ? _hsl(0, 78, 64) : _hsl(0, 70, 48),
    glassFill: dark
        ? const [Color(0x21FFFFFF), Color(0x0BFFFFFF), Color(0x05FFFFFF), Color(0x14FFFFFF)]
        : const [Color(0x94FFFFFF), Color(0x4DFFFFFF), Color(0x38FFFFFF), Color(0x70FFFFFF)],
    glassRim: dark
        ? const [Color(0xB3FFFFFF), Color(0x29FFFFFF), Color(0x00FFFFFF), Color(0x61FFFFFF)]
        : const [Color(0xFFFFFFFF), Color(0x80FFFFFF), Color(0x1AFFFFFF), Color(0xE6FFFFFF)],
    base: dark
        ? [_hsl(228, 40, 7), _hsl(256, 36, 9), _hsl(220, 42, 7)]
        : [_hsl(210, 60, 96), _hsl(270, 50, 96), _hsl(195, 60, 95)],
  );
  final glassSheet = dark ? const Color(0xFF1B1E25) : Colors.white;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'Outfit',
    fontFamilyFallback: const ['Manrope'],
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .englishLike
        .merge(dark ? Typography.whiteMountainView : Typography.blackMountainView)
        .apply(bodyColor: text, displayColor: text, fontFamily: 'Outfit'),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: text, elevation: 0, scrolledUnderElevation: 0),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: glassSheet, modalBackgroundColor: glassSheet),
    dialogTheme: DialogThemeData(backgroundColor: glassSheet),
    popupMenuTheme: PopupMenuThemeData(color: glassSheet),
    datePickerTheme: DatePickerThemeData(backgroundColor: glassSheet),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? _hsl(232, 30, 16) : _hsl(232, 30, 20),
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0x14FFFFFF) : const Color(0x99FFFFFF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: t.accent.withValues(alpha: 0.7), width: 1.5),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
        side: WidgetStatePropertyAll(BorderSide(color: dark ? const Color(0x29FFFFFF) : const Color(0x1F1E2850))),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accent.withValues(alpha: dark ? 0.32 : 0.22) : Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(text),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: t.accent.withValues(alpha: 0.22),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? t.accent : soft)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: s.contains(WidgetState.selected) ? t.accent : soft)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: t.accent.withValues(alpha: 0.22),
      selectedIconTheme: IconThemeData(color: t.accent),
      unselectedIconTheme: IconThemeData(color: soft),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
    extensions: [palette],
  );
}
