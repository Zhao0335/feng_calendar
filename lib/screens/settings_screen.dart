import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadInterests();
    });
  }

  // ── Logout ────────────────────────────────────────────────────────────────

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
    final baseUrl =
        prefs.getString('server_base_url') ?? 'http://101.37.80.57:5522';
    if (!mounted) return;
    await context.read<AuthService>().logout(baseUrl);
  }

  // ── Clear data ────────────────────────────────────────────────────────────

  Future<void> _clearData() async {
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
        _snack('本地数据已清除');
      }
    }
  }

  // ── Interests ─────────────────────────────────────────────────────────────

  Future<void> _deleteInterest(int id) async {
    try {
      await context.read<AppProvider>().deleteInterest(id);
      _snack('已删除', color: const Color(0xFF22C55E));
    } catch (e) {
      _snack('删除失败: $e');
    }
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => const _AddInterestDialog());
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16,
            MediaQuery.of(context).padding.bottom + 24),
        children: [
          // ── 账户 ───────────────────────────────────────────────────────────
          const _GroupLabel('账户'),
          _GroupCard(children: [
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
                child: Icon(Icons.person_rounded, size: 18, color: cs.primary),
              ),
              title: Text(
                context.watch<AuthService>().username ?? '未知用户',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('已登录',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
              trailing: TextButton(
                onPressed: _logout,
                child:
                    Text('退出', style: TextStyle(color: cs.error, fontSize: 13)),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── 用户画像 ────────────────────────────────────────────────────────
          Row(
            children: [
              const _GroupLabel('用户画像'),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加标签', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          Consumer<AppProvider>(
            builder: (_, provider, __) {
              if (provider.profileLoading && provider.interests.isEmpty) {
                return const _GroupCard(children: [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ]);
              }
              if (provider.interests.isEmpty) {
                return _GroupCard(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '暂无兴趣标签，点击右上角添加',
                      style: TextStyle(fontSize: 13, color: cs.outline),
                    ),
                  ),
                ]);
              }
              return _GroupCard(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: _InterestsContent(
                    interests: provider.interests,
                    onDelete: _deleteInterest,
                  ),
                ),
              ]);
            },
          ),

          const SizedBox(height: 24),

          // ── 数据管理 ────────────────────────────────────────────────────────
          const _GroupLabel('数据管理'),
          _GroupCard(children: [
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
              trailing:
                  Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
              onTap: _clearData,
            ),
          ]),

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

// ── Interests content ─────────────────────────────────────────────────────────

class _InterestsContent extends StatelessWidget {
  final List<Interest> interests;
  final void Function(int id) onDelete;

  const _InterestsContent(
      {required this.interests, required this.onDelete});

  static const _categories = [
    ('research', '研究领域', Icons.science_rounded),
    ('project', '项目类型', Icons.folder_rounded),
    ('skill', '技术技能', Icons.code_rounded),
  ];

  static const _colors = {
    'research': Color(0xFF6366F1),
    'project': Color(0xFFF97316),
    'skill': Color(0xFF22C55E),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    for (final (cat, label, icon) in _categories) {
      final items = interests.where((i) => i.category == cat).toList();
      if (items.isEmpty) continue;
      final color = _colors[cat] ?? cs.primary;

      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3)),
      ]));
      widgets.add(const SizedBox(height: 6));
      widgets.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.map((interest) {
          return Chip(
            avatar: Icon(icon, size: 13, color: color),
            label: Text(interest.tag),
            labelStyle: const TextStyle(fontSize: 12),
            deleteIconColor: cs.outline,
            onDeleted:
                interest.id != null ? () => onDelete(interest.id!) : null,
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            backgroundColor: color.withValues(alpha: 0.08),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

// ── Add Interest Dialog ───────────────────────────────────────────────────────

class _AddInterestDialog extends StatefulWidget {
  const _AddInterestDialog();

  @override
  State<_AddInterestDialog> createState() => _AddInterestDialogState();
}

class _AddInterestDialogState extends State<_AddInterestDialog> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'skill';
  String _tag = '';
  String _keywords = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('添加兴趣标签'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: const [
                DropdownMenuItem(value: 'research', child: Text('研究领域')),
                DropdownMenuItem(value: 'project', child: Text('项目类型')),
                DropdownMenuItem(value: 'skill', child: Text('技术技能')),
              ],
              onChanged: (v) => setState(() => _category = v!),
              decoration: InputDecoration(
                  labelText: '分类',
                  filled: true,
                  fillColor: cs.surfaceContainerLow),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                  labelText: '标签名称',
                  filled: true,
                  fillColor: cs.surfaceContainerLow),
              onSaved: (v) => _tag = v!,
              validator: (v) => v?.isEmpty ?? true ? '请输入标签名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: '关键词',
                hintText: '如：大模型、agent、pytorch（逗号分隔）',
                helperText: '中文关键词会自动翻译为英文',
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              onSaved: (v) => _keywords = v!,
              validator: (v) => v?.isEmpty ?? true ? '请输入关键词' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    try {
      await context.read<AppProvider>().addInterest(
            category: _category,
            tag: _tag,
            keywords: _keywords.split(',').map((k) => k.trim()).toList(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('添加失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
