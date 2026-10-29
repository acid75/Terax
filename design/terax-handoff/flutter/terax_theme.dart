// Terax design system — Flutter theme.
// Source of truth: design-system/tokens.json. Keep values in sync with it.
//
// Usage:
//   MaterialApp(theme: TeraxTheme.build(TeraxPlatform.current), ...)
//   final c = TeraxColors.of(context);  // colors
//   Text('Hola', style: TeraxText.label.copyWith(color: c.text));
//
// pubspec.yaml (fonts):
//   flutter:
//     fonts:
//       - family: Figtree
//         fonts:
//           - asset: assets/fonts/Figtree-VariableFont_wght.ttf
//       - family: GeistMono
//         fonts:
//           - asset: assets/fonts/GeistMono-Regular.ttf
//             weight: 400
//           - asset: assets/fonts/GeistMono-Medium.ttf
//             weight: 500
// (Flutter needs TTF/OTF; the .woff2 files in design-system/fonts are for the web.
//  Download Figtree and Geist Mono TTFs from Google Fonts, both OFL.)

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum TeraxPlatform {
  windows,
  android;

  static TeraxPlatform get current =>
      (!kIsWeb && Platform.isAndroid) ? TeraxPlatform.android : TeraxPlatform.windows;
}

@immutable
class TeraxColors extends ThemeExtension<TeraxColors> {
  const TeraxColors({
    required this.bg,
    required this.glow,
    required this.surface,
    required this.scrim,
    required this.outline,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.mint,
    required this.onMint,
    required this.danger,
    required this.onDanger,
    required this.iconContainer,
    required this.iconRing,
    required this.iconOnContainer,
    required this.controlOff,
    required this.illustrationLine,
  });

  /// Page / window background.
  final Color bg;
  /// Android only: soft light behind the header, fades to [bg]. Equals [bg] on Windows.
  final Color glow;
  /// Cards, tiles, sheets. Barely differs from [bg]: fields also need [outline].
  final Color surface;
  final Color scrim;
  /// 1px border of search field and segmented control.
  final Color outline;
  final Color divider;
  final Color text;
  /// Secondary text, placeholders, neutral icons.
  final Color textMuted;
  /// Selected segment fill only.
  final Color accent;
  final Color onAccent;
  /// Actions: primary button fill, switch on, text actions.
  final Color mint;
  final Color onMint;
  /// Destructive actions and errors. Always with an icon and a word.
  final Color danger;
  final Color onDanger;
  final Color iconContainer;
  final Color iconRing;
  final Color iconOnContainer;
  final Color controlOff;
  /// Decorative empty-state line art only.
  final Color illustrationLine;

  static const windows = TeraxColors(
    bg: Color(0xFF0B1016),
    glow: Color(0xFF0B1016),
    surface: Color(0xFF141D27),
    scrim: Color(0x80000000),
    outline: Color(0xFF344556),
    divider: Color(0xFF898E93),
    text: Color(0xFFF3F6FA),
    textMuted: Color(0xFFABB8CB),
    accent: Color(0xFF03DAC6),
    onAccent: Color(0xFF000000),
    mint: Color(0xFF9BE9DD),
    onMint: Color(0xFF082A22),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
    iconContainer: Color(0xFF141D27),
    iconRing: Color(0xFF2C3B4B),
    iconOnContainer: Color(0xFFF3F6FA),
    controlOff: Color(0xFF3C4A59),
    illustrationLine: Color(0xFF3D5C5B),
  );

  static const android = TeraxColors(
    bg: Color(0xFF0C0F14),
    glow: Color(0xFF42464A),
    surface: Color(0xFF161D27),
    scrim: Color(0x80000000),
    outline: Color(0xFF3A4853),
    divider: Color(0xFF3A4853), // redesign: quieter than the current near-white line
    text: Color(0xFFF3F6FA),
    textMuted: Color(0xFFABB8CB),
    accent: Color(0xFF62D7C5),
    onAccent: Color(0xFF0C0F14),
    mint: Color(0xFFABE7DD),
    onMint: Color(0xFF122921),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
    iconContainer: Color(0xFF334549),
    iconRing: Color(0xFF73888D),
    iconOnContainer: Color(0xFFABE7DD),
    controlOff: Color(0xFF3C4A59),
    illustrationLine: Color(0xFF3D5C5B),
  );

  static TeraxColors forPlatform(TeraxPlatform p) =>
      p == TeraxPlatform.android ? android : windows;

  static TeraxColors of(BuildContext context) =>
      Theme.of(context).extension<TeraxColors>() ?? windows;

  @override
  TeraxColors copyWith() => this;

  @override
  TeraxColors lerp(ThemeExtension<TeraxColors>? other, double t) =>
      (other is TeraxColors && t >= 0.5) ? other : this;
}

/// Type styles (sizes in logical px). Colors are applied by the caller.
class TeraxText {
  static const String ui = 'Figtree';
  static const String mono = 'GeistMono';
  static const List<String> uiFallback = ['Segoe UI', 'Roboto'];

  static const display = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w600);
  static const title = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w400);
  static const headline = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600);
  static const bodyLg = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 16, height: 26 / 16, fontWeight: FontWeight.w400);
  static const body = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const labelSm = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);
  static const caption = TextStyle(fontFamily: ui, fontFamilyFallback: uiFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  /// IPs, technical device names, file sizes.
  static const monoSm = TextStyle(fontFamily: mono, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  /// Connection code the user reads or copies.
  static const code = TextStyle(fontFamily: mono, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w500, letterSpacing: 1);
}

class TeraxSpace {
  static const double s6 = 6;   // grid tile gap (use 4 on Android grid)
  static const double s12 = 12; // between stacked controls; icon to text
  static const double s16 = 16; // card and row padding
  static const double s18 = 18; // after the device card (Windows)
  static const double s20 = 20; // Android screen margin
  static const double s48 = 48; // Windows content margin
}

class TeraxRadius {
  static const double sm = 8;      // tiles, search (Windows)
  static const double md = 10;     // segmented control (Windows)
  static const double lg = 12;     // device card, primary button (Windows)
  static const double sheet = 28;  // top corners of sheets, dialogs
  static const double full = 999;  // switches, pills, Android segmented control
}

/// Control sizes. Android values are larger for touch (min target 48dp).
class TeraxSize {
  final double segment, button, input, deviceCard, buttonRadius, cardRadius;
  const TeraxSize._(this.segment, this.button, this.input, this.deviceCard, this.buttonRadius, this.cardRadius);
  static const windows = TeraxSize._(32, 42, 48, 60, 12, 12);
  static const android = TeraxSize._(44, 52, 56, 60, 16, 18);
  static TeraxSize forPlatform(TeraxPlatform p) => p == TeraxPlatform.android ? android : windows;
}

/// Motion. See design/handoff/SPEC.md § Movimiento. Honour MediaQuery.disableAnimations.
class TeraxMotion {
  static const exit = Cubic(0.2, 0, 0, 1);   // things leaving / settling
  static const enter = Cubic(0.4, 0, 1, 1);  // things being thrown away
  static const lift = Duration(milliseconds: 180);
  static const edgeZoneIn = Duration(milliseconds: 220);
  static const zoneHover = Duration(milliseconds: 150);
  static const drop = Duration(milliseconds: 280);
  static const cancelReturn = Duration(milliseconds: 320);
  static const previewExit = Duration(milliseconds: 240);
  static const previewReturn = Duration(milliseconds: 280);
  static const arrivalLight = Duration(milliseconds: 200);
  static const arrivalWave = Duration(milliseconds: 900);
  static const arrivalThumb = Duration(milliseconds: 420);
  static const verifiedCheck = Duration(milliseconds: 200);
  static const minTransfer = Duration(milliseconds: 600);   // even for tiny files
  static const autoOpenDelay = Duration(milliseconds: 1200); // after verification
  static const longPress = Duration(milliseconds: 350);
  static const previewSwipeThreshold = 0.35; // fraction of height
  static const previewSwipeVelocity = 1000.0; // dp/s
  static const edgeZoneHeight = 120.0; // dp from the top edge

  static bool reduced(BuildContext context) => MediaQuery.of(context).disableAnimations;
}

class TeraxTheme {
  static ThemeData build(TeraxPlatform p) {
    final c = TeraxColors.forPlatform(p);
    final s = TeraxSize.forPlatform(p);
    final scheme = ColorScheme.dark(
      surface: c.bg,
      onSurface: c.text,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      onSurfaceVariant: c.textMuted,
      primary: c.mint,
      onPrimary: c.onMint,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onDanger,
      outline: c.outline,
      outlineVariant: c.divider,
      scrim: c.scrim,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      fontFamily: TeraxText.ui,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.mint,
          foregroundColor: c.onMint,
          minimumSize: Size(64, s.button),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.buttonRadius)),
          textStyle: TeraxText.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.mint,
          minimumSize: const Size(48, 44),
          textStyle: TeraxText.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.outline),
          minimumSize: Size(64, s.button),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.buttonRadius)),
          textStyle: TeraxText.label,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.mint : Colors.transparent),
        thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.onMint : c.controlOff),
        trackOutlineColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.mint : c.controlOff),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: TeraxText.body.copyWith(color: c.textMuted),
        prefixIconColor: c.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p == TeraxPlatform.android ? 999 : TeraxRadius.sm),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p == TeraxPlatform.android ? 999 : TeraxRadius.sm),
          borderSide: BorderSide(color: c.mint, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        showDragHandle: true,
        dragHandleColor: c.textMuted,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(TeraxRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TeraxRadius.sheet)),
        titleTextStyle: TeraxText.headline.copyWith(color: c.text),
        contentTextStyle: TeraxText.caption.copyWith(color: c.textMuted, fontSize: 14, height: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface,
        contentTextStyle: TeraxText.caption.copyWith(color: c.text),
        actionTextColor: c.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.mint, linearTrackColor: c.bg),
    );
  }
}
