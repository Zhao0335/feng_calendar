import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadInterests();
      context.read<AppProvider>().loadProfileSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('用户画像'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddInterestDialog(context),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (_, provider, __) {
          if (provider.profileLoading && provider.interests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.interests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        size: 36, color: cs.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('暂无兴趣标签',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 6),
                  Text('点击右上角 + 添加',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (provider.profileSummary != null)
                _buildSummaryCard(provider.profileSummary!, cs),
              const SizedBox(height: 16),
              _buildCategorySection(
                  'research', '研究领域', Icons.science_rounded, cs.primary, cs,
                  provider.interests),
              _buildCategorySection(
                  'project', '项目类型', Icons.folder_rounded,
                  const Color(0xFFF97316), cs, provider.interests),
              _buildCategorySection(
                  'skill', '技术技能', Icons.code_rounded, cs.tertiary, cs,
                  provider.interests),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary, ColorScheme cs) {
    final total = summary['total_interests'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.4),
            cs.tertiaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 28, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('画像概览',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text('共 $total 个兴趣标签',
                    style: TextStyle(fontSize: 13, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    String title,
    IconData icon,
    Color color,
    ColorScheme cs,
    List<Interest> interests,
  ) {
    final categoryInterests =
        interests.where((i) => i.category == category).toList();
    if (categoryInterests.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                  letterSpacing: 0.3,
                )),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categoryInterests.map((interest) {
            return Chip(
              avatar: Icon(icon, size: 14, color: color),
              label: Text(interest.tag),
              labelStyle: const TextStyle(fontSize: 13),
              deleteIconColor: cs.outline,
              onDeleted: interest.id != null
                  ? () => _deleteInterest(interest.id!)
                  : null,
              side: BorderSide(color: color.withValues(alpha: 0.3)),
              backgroundColor: color.withValues(alpha: 0.08),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _deleteInterest(int interestId) async {
    try {
      await context.read<AppProvider>().deleteInterest(interestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('删除成功'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('删除失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  void _showAddInterestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddInterestDialog(),
    );
  }
}

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
              onChanged: (value) => setState(() => _category = value!),
              decoration: InputDecoration(
                labelText: '分类',
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: '标签名称',
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              onSaved: (value) => _tag = value!,
              validator: (value) =>
                  value?.isEmpty ?? true ? '请输入标签名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: '关键词',
                hintText: '用逗号分隔，如：python, programming',
                filled: true,
                fillColor: cs.surfaceContainerLow,
              ),
              onSaved: (value) => _keywords = value!,
              validator: (value) =>
                  value?.isEmpty ?? true ? '请输入关键词' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('添加'),
        ),
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
