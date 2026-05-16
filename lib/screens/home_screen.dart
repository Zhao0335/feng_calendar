import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'input_screen.dart';
import 'items_screen.dart';
import 'recommendations_screen.dart';
import 'daily_report_screen.dart';
import 'settings_screen.dart';
import '../widgets/floating_chat_button.dart';
import 'chat_planning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  AppProvider? _provider;
  bool _extractionNavigated = false;

  static const _fileChannel =
      MethodChannel('com.example.fengCalendar/file_open');

  static const _screens = [
    InputScreen(),
    ItemsScreen(),
    RecommendationsScreen(),
    DailyReportScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    (Icons.add_circle_outline_rounded, Icons.add_circle_rounded, '输入'),
    (Icons.calendar_month_outlined,    Icons.calendar_month_rounded, '日程'),
    (Icons.recommend_outlined,         Icons.recommend_rounded,      '推荐'),
    (Icons.article_outlined,           Icons.article_rounded,        '日报'),
    (Icons.settings_outlined,          Icons.settings_rounded,       '设置'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<AppProvider>();
      _provider!.loadLocal();
      _provider!.addListener(_onProviderChange);
      if (!kIsWeb) {
        _fileChannel.setMethodCallHandler(_handleFileOpen);
        _checkPendingFile();
      }
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChange);
    super.dispose();
  }

  void _onProviderChange() {
    final status = _provider?.status;
    if (status == ExtractionStatus.loading) {
      _extractionNavigated = false;
    } else if (status == ExtractionStatus.success && !_extractionNavigated) {
      _extractionNavigated = true;
      setState(() => _currentIndex = 1);
    }
    if (_provider?.pendingFilePath != null && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  Future<dynamic> _handleFileOpen(MethodCall call) async {
    if (call.method == 'openFile') {
      final path = call.arguments as String?;
      if (path != null) {
        _provider?.setPendingFile(path);
        if (mounted) setState(() => _currentIndex = 0);
      }
    }
  }

  Future<void> _checkPendingFile() async {
    try {
      final path = await _fileChannel.invokeMethod<String>('getPendingFile');
      if (path != null) {
        _provider?.setPendingFile(path);
        if (mounted) setState(() => _currentIndex = 0);
      }
    } catch (_) {}
  }

  void _openChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ChatPlanningScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 ? _buildWideLayout() : _buildNarrowLayout();
  }

  // ── Wide layout (sidebar) ─────────────────────────────────────────────────

  Widget _buildWideLayout() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          _SideRail(
            selectedIndex: _currentIndex,
            onTap: _onNavTap,
            items: _navItems,
          ),
          VerticalDivider(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(index: _currentIndex, children: _screens),
                FloatingChatButton(onTap: _openChat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout (bottom nav) ────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          FloatingChatButton(onTap: _openChat),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
      ),
    );
  }
}

// ── Floating bottom nav bar ───────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainer.withValues(alpha: 0.92)
                    : cs.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  return _NavItem(
                    icon: items[i].$1,
                    activeIcon: items[i].$2,
                    label: items[i].$3,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer.withValues(alpha: 0.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  ),
                  child: child,
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Side rail (wide layout) ───────────────────────────────────────────────────

class _SideRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;

  const _SideRail({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // App logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.tertiary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_month_rounded,
                color: cs.onPrimary, size: 22),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: List.generate(items.length, (i) {
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SideRailItem(
                    icon: items[i].$1,
                    activeIcon: items[i].$2,
                    label: items[i].$3,
                    selected: selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SideRailItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideRailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
