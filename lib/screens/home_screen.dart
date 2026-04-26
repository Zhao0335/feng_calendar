import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'input_screen.dart';
import 'items_screen.dart';
import 'settings_screen.dart';

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
    SettingsScreen(),
  ];

  final _labels = const ['输入', '列表', '设置'];
  final _icons = const [
    Icons.add_circle_outline,
    Icons.list_alt_outlined,
    Icons.settings_outlined,
  ];
  final _activeIcons = const [
    Icons.add_circle,
    Icons.list_alt,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<AppProvider>();
      _provider!.loadLocal();
      _provider!.addListener(_onProviderChange);
      if (Platform.isIOS) {
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
    // Switch to input tab when a file is waiting to be imported
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
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: _screens[_currentIndex],
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
