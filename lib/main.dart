import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  final authService = AuthService();
  await authService.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ProxyProvider<AuthService, ApiService>(
          create: (ctx) => ApiService(auth: ctx.read<AuthService>()),
          update: (_, auth, prev) => prev ?? ApiService(auth: auth),
        ),
        Provider<StorageService>(create: (_) => StorageService()),
        ChangeNotifierProxyProvider2<ApiService, StorageService, AppProvider>(
          create: (ctx) => AppProvider(
            api: ctx.read<ApiService>(),
            storage: ctx.read<StorageService>(),
          ),
          update: (_, api, storage, prev) =>
              prev ?? AppProvider(api: api, storage: storage),
        ),
      ],
      child: const ScheduleApp(),
    ),
  );
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '枫枫子的备忘录',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B4CF5),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? scheme.surfaceContainer : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
      ),

      // ── Input fields ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 14),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),

      // ── Dialogs ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(64, 44),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(64, 44),
        ),
      ),

      // ── Tabs ─────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
        unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: scheme.onSurfaceVariant),
        overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: 0.08)),
      ),

      // ── Segmented button ─────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),

      // ── List tiles ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minVerticalPadding: 8,
      ),

      // ── Scaffold ─────────────────────────────────────────────────────────
      scaffoldBackgroundColor: isDark
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLowest,
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthService>().isLoggedIn;
    return isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}
