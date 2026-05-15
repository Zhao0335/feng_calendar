import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'input_screen.dart';
import 'items_screen.dart';
import 'profile_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  AppProvider? _provider;

  static const _fileChannel =
      MethodChannel('com.example.fengCalendar/file_open');

  final _screens = const [
    InputScreen(),
    ItemsScreen(),
    ProfileScreen(),
    RecommendationsScreen(),
    DailyReportScreen(),
    SettingsScreen(),
  ];

  final _labels = const ['输入', '列表', '画像', '推荐', '日报', '设置'];
  final _icons = const [
    Icons.add_circle_outline,
    Icons.list_alt_outlined,
    Icons.person_outline_rounded,
    Icons.recommend_outlined,
    Icons.article_outlined,
    Icons.settings_outlined,
  ];
  final _activeIcons = const [
    Icons.add_circle,
    Icons.list_alt,
    Icons.person_rounded,
    Icons.recommend_rounded,
    Icons.article_rounded,
    Icons.settings,
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
    if (_provider?.status == ExtractionStatus.success && _currentIndex != 1) {
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
      final path =
          await _fileChannel.invokeMethod<String>('getPendingFile');
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
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return _buildWideLayout();
    return _buildNarrowLayout();
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const SizedBox(height: 16),
            destinations: List.generate(
              _labels.length,
              (i) => NavigationRailDestination(
                icon: Icon(_icons[i]),
                selectedIcon: Icon(_activeIcons[i]),
                label: Text(_labels[i]),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Stack(
              children: [
                _screens[_currentIndex],
                FloatingChatButton(onTap: _openChat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          FloatingChatButton(onTap: _openChat),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: List.generate(
          _labels.length,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_activeIcons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
