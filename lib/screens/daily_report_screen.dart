import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadTodayReport();
      provider.loadReportHistory();
      provider.loadArxivPreference();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('arXiv 日报'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(child: Text('今日日报')),
                Tab(child: Text('历史')),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showPreferenceDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(cs),
          _buildHistoryTab(cs),
        ],
      ),
    );
  }

  Widget _buildTodayTab(ColorScheme cs) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        if (provider.reportLoading && provider.todayReport == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = provider.todayReport;
        if (report == null) {
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
                  child: Icon(Icons.article_outlined,
                      size: 36, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text('今日日报尚未生成',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: cs.onSurface)),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => _generateReport(provider),
                  child: const Text('生成日报'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadTodayReport(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildReportHeader(report, cs),
              const SizedBox(height: 16),
              if (report.summary != null && report.summary!.isNotEmpty)
                _buildReportContent(report.summary!, cs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportHeader(ArxivReport report, ColorScheme cs) {
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
          Icon(Icons.auto_stories_rounded, size: 28, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('arXiv 学术日报',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(report.reportDate ?? '',
                    style: TextStyle(fontSize: 13, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(String content, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: SelectableText(
        content,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ColorScheme cs) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        if (provider.reportLoading && provider.reportHistory.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.reportHistory.isEmpty) {
          return Center(
            child: Text('暂无历史日报',
                style: TextStyle(color: cs.outline, fontSize: 14)),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadReportHistory(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: provider.reportHistory.length,
            itemBuilder: (context, index) {
              final report = provider.reportHistory[index];
              return _buildHistoryCard(report, cs);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(ArxivReport report, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (report.summary != null) {
            _showReportDetail(report);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.article_rounded,
                    size: 20, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('arXiv 日报',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(report.reportDate ?? '',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetail(ArxivReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) {
          final cs = Theme.of(context).colorScheme;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('${report.reportDate ?? ''} 日报',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: cs.onSurface)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: SelectableText(
                    report.summary ?? '',
                    style: TextStyle(
                        fontSize: 14, height: 1.7, color: cs.onSurface),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateReport(AppProvider provider) async {
    try {
      await provider.generateReport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('日报生成成功'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('生成失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  void _showPreferenceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _PreferenceDialog(),
    );
  }
}

class _PreferenceDialog extends StatefulWidget {
  const _PreferenceDialog();

  @override
  State<_PreferenceDialog> createState() => _PreferenceDialogState();
}

class _PreferenceDialogState extends State<_PreferenceDialog> {
  late TimeOfDay _pushTime;
  late int _paperCount;
  late List<String> _categories;
  late bool _isEnabled;

  static const _availableCategories = [
    'cs.AI',
    'cs.CV',
    'cs.LG',
    'cs.CL',
    'cs.NE',
    'cs.RO',
    'cs.SE',
    'stat.ML',
  ];

  @override
  void initState() {
    super.initState();
    final pref = context.read<AppProvider>().arxivPreference;
    _pushTime = _parseTime(pref.pushTime);
    _paperCount = pref.paperCount;
    _categories = List.from(pref.categories);
    _isEnabled = pref.isEnabled;
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('日报偏好设置'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('启用日报推送'),
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              title: const Text('推送时间'),
              subtitle: Text(_pushTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _pushTime,
                );
                if (time != null) setState(() => _pushTime = time);
              },
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              title: const Text('论文数量'),
              subtitle: Text('$_paperCount 篇'),
              contentPadding: EdgeInsets.zero,
            ),
            Slider(
              value: _paperCount.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_paperCount',
              onChanged: (v) => setState(() => _paperCount = v.round()),
            ),
            const SizedBox(height: 8),
            Text('领域分类',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableCategories.map((cat) {
                final selected = _categories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (s) {
                    setState(() {
                      if (s) {
                        _categories.add(cat);
                      } else {
                        _categories.remove(cat);
                      }
                    });
                  },
                  selectedColor: cs.primaryContainer,
                );
              }).toList(),
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
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    try {
      await context.read<AppProvider>().updateArxivPreference(
            pushTime:
                '${_pushTime.hour.toString().padLeft(2, '0')}:${_pushTime.minute.toString().padLeft(2, '0')}',
            paperCount: _paperCount,
            categories: _categories,
            isEnabled: _isEnabled,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('偏好已更新'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('保存失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }
}
