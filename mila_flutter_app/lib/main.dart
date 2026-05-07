import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/livekit_service.dart';
import 'services/settings_service.dart';
import 'services/token_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState(
    settingsService: SettingsService(),
    tokenService: TokenService(),
    liveKitService: LiveKitService(),
  );

  await appState.initialize();

  runApp(MilaApp(appState: appState));
}

class MilaApp extends StatelessWidget {
  const MilaApp({required this.appState, super.key});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    const blue500 = Color(0xFF002CF2);
    const lightBackground = Color(0xFFF9F9F6);
    const darkBackground = Color(0xFF070707);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue500,
        brightness: Brightness.light,
        primary: blue500,
        surface: const Color(0xFFF3F3F1),
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: Color(0xFF404040),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: Color(0xFF505050),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          fontFamily: 'monospace',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF111111),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF111111)),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFEDEDEA),
        selectedColor: blue500.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue500,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111111),
          side: const BorderSide(color: Color(0xFFDBDBD8)),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFDBDBD8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFDBDBD8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: blue500, width: 1.5),
        ),
      ),
      dividerColor: const Color(0xFFE5E5E1),
      extensions: const <ThemeExtension<dynamic>>[
        MilaPalette(
          blue500: blue500,
          darkBackground: darkBackground,
          darkSurface: Color(0xFF131313),
          darkOutline: Color(0xFF202020),
          lightBackground: lightBackground,
          lightSurface: Color(0xFFF3F3F1),
          lightOutline: Color(0xFFDBDBD8),
          signalActive: Color(0xFF1FF968),
        ),
      ],
    );

    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        title: 'Mila',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const HomeScreen(),
      ),
    );
  }
}

@immutable
class MilaPalette extends ThemeExtension<MilaPalette> {
  const MilaPalette({
    required this.blue500,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkOutline,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightOutline,
    required this.signalActive,
  });

  final Color blue500;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkOutline;
  final Color lightBackground;
  final Color lightSurface;
  final Color lightOutline;
  final Color signalActive;

  @override
  MilaPalette copyWith({
    Color? blue500,
    Color? darkBackground,
    Color? darkSurface,
    Color? darkOutline,
    Color? lightBackground,
    Color? lightSurface,
    Color? lightOutline,
    Color? signalActive,
  }) {
    return MilaPalette(
      blue500: blue500 ?? this.blue500,
      darkBackground: darkBackground ?? this.darkBackground,
      darkSurface: darkSurface ?? this.darkSurface,
      darkOutline: darkOutline ?? this.darkOutline,
      lightBackground: lightBackground ?? this.lightBackground,
      lightSurface: lightSurface ?? this.lightSurface,
      lightOutline: lightOutline ?? this.lightOutline,
      signalActive: signalActive ?? this.signalActive,
    );
  }

  @override
  MilaPalette lerp(ThemeExtension<MilaPalette>? other, double t) {
    if (other is! MilaPalette) {
      return this;
    }

    return MilaPalette(
      blue500: Color.lerp(blue500, other.blue500, t)!,
      darkBackground: Color.lerp(darkBackground, other.darkBackground, t)!,
      darkSurface: Color.lerp(darkSurface, other.darkSurface, t)!,
      darkOutline: Color.lerp(darkOutline, other.darkOutline, t)!,
      lightBackground: Color.lerp(lightBackground, other.lightBackground, t)!,
      lightSurface: Color.lerp(lightSurface, other.lightSurface, t)!,
      lightOutline: Color.lerp(lightOutline, other.lightOutline, t)!,
      signalActive: Color.lerp(signalActive, other.signalActive, t)!,
    );
  }
}
