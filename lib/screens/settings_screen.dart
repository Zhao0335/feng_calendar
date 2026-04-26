import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isChecking = false;
  bool? _connectionOk;

  static const _modelKey = 'model_name';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text =
          prefs.getString('server_base_url') ?? 'http://192.168.1.100:8000';
      _modelController.text = prefs.getString(_modelKey) ?? 'qwen2.5:72b';
    });
  }

  Future<void> _saveSettings() async {
    await context.read<ApiService>().setBaseUrl(_urlController.text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, _modelController.text.trim());
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
      _connectionOk = null;
    });
    await _saveSettings();
    final ok = await context.read<ApiService>().healthCheck();
    setState(() {
      _isChecking = false;
      _connectionOk = ok;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确认退出当前账户？本地数据不会删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('server_base_url') ?? 'http://101.37.80.57:5522';
    if (!mounted) return;
    await context.read<AuthService>().logout(baseUrl);
  }

  Future<void> _clearData() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('将删除所有本地日程和待办，无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清除')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppProvider>().clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('本地数据已清除'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _GroupLabel('账户'),
          _GroupCard(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_rounded,
                      size: 18, color: cs.primary),
                ),
                title: Text(
                  context.watch<AuthService>().username ?? '未知用户',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('已登录',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                trailing: TextButton(
                  onPressed: _logout,
                  child: Text('退出',
                      style: TextStyle(color: cs.error, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _GroupLabel('服务器连接'),
          _GroupCard(
            children: [
              _FieldTile(
                icon: Icons.dns_rounded,
                iconColor: cs.primary,
                label: '服务器地址',
                controller: _urlController,
                hint: 'http://192.168.1.100:8000',
                onEditingComplete: _saveSettings,
              ),
              _Divider(),
              _FieldTile(
                icon: Icons.auto_awesome_rounded,
                iconColor: cs.tertiary,
                label: '模型名称',
                controller: _modelController,
                hint: 'qwen2.5:72b',
                onEditingComplete: _saveSettings,
              ),
              _Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _isChecking ? null : _checkConnection,
                        child: _isChecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('测试连接'),
                      ),
                    ),
                    if (_connectionOk != null) ...[
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Row(
                          key: ValueKey(_connectionOk),
                          children: [
                            Icon(
                              _connectionOk!
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 18,
                              color: _connectionOk!
                                  ? const Color(0xFF22C55E)
                                  : cs.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _connectionOk! ? '连接正常' : '连接失败',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _connectionOk!
                                    ? const Color(0xFF22C55E)
                                    : cs.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _GroupLabel('数据管理'),
          _GroupCard(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_rounded,
                      size: 18, color: cs.onErrorContainer),
                ),
                title: const Text('清除本地数据',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('删除所有日程和待办记录',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                trailing: Icon(Icons.chevron_right_rounded,
                    size: 18, color: cs.outline),
                onTap: _clearData,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '日程助手 v1.0.0',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onEditingComplete;

  const _FieldTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controller,
    required this.hint,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onEditingComplete: onEditingComplete,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                hintStyle: TextStyle(color: cs.outline, fontSize: 13),
                labelStyle: TextStyle(color: cs.outline, fontSize: 13),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
