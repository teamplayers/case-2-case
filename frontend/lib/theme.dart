import 'package:flutter/material.dart';

const iosBlue = Color(0xFF007AFF);
const iosGreen = Color(0xFF34C759);
const iosOrange = Color(0xFFFF9500);
const iosRed = Color(0xFFFF3B30);
const iosPurple = Color(0xFF5856D6);
const iosTeal = Color(0xFF5AC8FA);
const iosGray = Color(0xFF8E8E93);
const iosGray4 = Color(0xFFD1D1D6);
const iosGray5 = Color(0xFFE5E5EA);
const iosGray6 = Color(0xFFF2F2F7);
const iosLabel = Color(0xFF1C1C1E);
const iosSecondary = Color(0xFF8E8E93);
const iosTertiary = Color(0xFFC7C7CC);
const iosSeparator = Color(0xFFC6C6C8);
const iosFill = Color(0x14787880);

const ink = iosLabel;
const muted = iosSecondary;
const paper = iosGray6;
const accent = iosBlue;
const accent2 = iosOrange;

const iosFontFallback = <String>[
  '.SF Pro Text',
  'SF Pro Text',
  '-apple-system',
  'BlinkMacSystemFont',
  'Helvetica Neue',
  'Segoe UI',
  'Roboto',
];

ThemeData appTheme() {
  const text = TextTheme(
    displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: iosLabel, height: 1.15),
    headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, color: iosLabel, height: 1.15),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36, color: iosLabel, height: 1.2),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35, color: iosLabel),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: iosLabel),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: iosLabel),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: iosLabel),
    bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: iosLabel, height: 1.35),
    bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: iosLabel, height: 1.35),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: iosSecondary, height: 1.3),
    labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: iosBlue),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: iosSecondary, letterSpacing: 0.2),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: iosSecondary, letterSpacing: 0.4),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamilyFallback: iosFontFallback,
    colorScheme: const ColorScheme.light(
      primary: iosBlue,
      onPrimary: Colors.white,
      secondary: iosPurple,
      surface: Colors.white,
      onSurface: iosLabel,
      error: iosRed,
    ),
    scaffoldBackgroundColor: iosGray6,
    canvasColor: iosGray6,
    dividerColor: iosSeparator.withValues(alpha: 0.6),
    splashFactory: NoSplash.splashFactory,
    highlightColor: iosGray5,
    textTheme: text,
    primaryTextTheme: text,
    iconTheme: const IconThemeData(color: iosBlue, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF0F2F2F7),
      foregroundColor: iosLabel,
      elevation: 0,
      scrolledUnderElevation: 0.4,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: iosLabel, fontFamilyFallback: iosFontFallback),
      iconTheme: IconThemeData(color: iosBlue, size: 22),
      actionsIconTheme: IconThemeData(color: iosBlue, size: 22),
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF0F9F9F9),
      elevation: 0,
      height: 58,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: selected ? iosBlue : iosSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? iosBlue : iosSecondary, size: 24);
      }),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      hintStyle: TextStyle(color: iosSecondary, fontSize: 17, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(color: iosSecondary, fontSize: 17),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: iosBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: iosBlue.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: iosBlue,
        side: const BorderSide(color: iosGray5),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: iosBlue,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: iosGray5,
      selectedColor: iosBlue.withValues(alpha: 0.14),
      labelStyle: const TextStyle(fontSize: 14, color: iosLabel),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(
      color: iosSeparator.withValues(alpha: 0.55),
      thickness: 0.5,
      space: 0.5,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: iosSecondary,
      textColor: iosLabel,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(border: InputBorder.none),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: iosBlue),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: _NoSlideTransitionsBuilder(),
        TargetPlatform.macOS: _NoSlideTransitionsBuilder(),
        TargetPlatform.android: _NoSlideTransitionsBuilder(),
        TargetPlatform.linux: _NoSlideTransitionsBuilder(),
        TargetPlatform.windows: _NoSlideTransitionsBuilder(),
      },
    ),
  );
}

class _NoSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _NoSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

String stageLabel(String stage) => stage == 'resolved' ? 'Closed' : _titleCase(stage);

String _titleCase(String s) {
  if (s.isEmpty) return s;
  if (s == 'wip') return 'In progress';
  return s[0].toUpperCase() + s.substring(1);
}

Color stageTint(String stage) {
  switch (stage) {
    case 'open':
      return iosBlue;
    case 'assigned':
      return iosOrange;
    case 'wip':
      return iosPurple;
    case 'resolved':
      return iosGreen;
    default:
      return iosGray;
  }
}

String caseTypeOf(Map c) => '${c['type'] ?? c['workspaceType'] ?? ''}';

String typeLabel(String type) {
  switch (type) {
    case 'complaint':
      return 'Complaint';
    case 'bug':
      return 'Bug';
    case 'feedback':
      return 'Feedback';
    case 'request':
      return 'Request';
    case 'ticket':
      return 'Ticket';
    default:
      return type;
  }
}

Color typeTint(String type) {
  switch (type) {
    case 'complaint':
      return iosOrange;
    case 'bug':
      return iosRed;
    case 'feedback':
      return iosTeal;
    case 'request':
      return iosPurple;
    case 'ticket':
      return iosBlue;
    default:
      return iosGray;
  }
}

class IosBadge extends StatelessWidget {
  const IosBadge(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? iosGray;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tint, letterSpacing: -0.1),
      ),
    );
  }
}

typedef StatusChip = IosBadge;
