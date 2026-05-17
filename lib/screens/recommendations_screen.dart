import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import 'paper_reader_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadRecommendations();
    });
  }

  // Shuffle the list while keeping each source's internal order,
  // then randomly interleave them so results feel fresh each load.
  List<RecommendationItem> _shuffled(List<RecommendationItem> items) {
    final rng = Random();
    final bySource = <String, List<RecommendationItem>>{};
    for (final item in items) {
      bySource.putIfAbsent(item.source, () => []).add(item);
    }
    // Shuffle within each source
    for (final list in bySource.values) {
      list.shuffle(rng);
    }
    // Randomly interleave
    final result = <RecommendationItem>[];
    final queues = bySource.values.map((l) => [...l]).toList();
    while (queues.any((q) => q.isNotEmpty)) {
      // Pick a random non-empty queue
      final active = queues.where((q) => q.isNotEmpty).toList();
      final chosen = active[rng.nextInt(active.length)];
      result.add(chosen.removeAt(0));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('推荐'),
        actions: [
          FilterChip(
            label: Text(_unreadOnly ? '未读' : '全部'),
            selected: _unreadOnly,
            onSelected: (selected) {
              setState(() => _unreadOnly = selected);
              context.read<AppProvider>().loadRecommendations(unreadOnly: selected);
            },
            selectedColor: cs.primaryContainer,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新推荐',
            onPressed: _refreshRecommendations,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (_, provider, __) {
          if (provider.recommendationsLoading && provider.recommendations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.recommendations.isEmpty) {
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
                    child: Icon(Icons.recommend_outlined, size: 36, color: cs.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('暂无推荐内容',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 6),
                  Text('完善用户画像后可获得个性化推荐',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline)),
                ],
              ),
            );
          }

          final displayed = _shuffled(provider.recommendations);

          return RefreshIndicator(
            onRefresh: () => provider.loadRecommendations(unreadOnly: _unreadOnly),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16,
                  MediaQuery.of(context).padding.bottom + 24),
              itemCount: displayed.length,
              itemBuilder: (context, index) {
                final item = displayed[index];
                return _RecommendationCard(
                  item: item,
                  onOpen: () => _openItem(item),
                  onSave: () => _saveItem(item),
                  onRead: (item.source == 'arxiv' || item.source == 'huggingface')
                      ? () => _openItem(item)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Extract arXiv ID from URL like https://arxiv.org/abs/2301.12345
  String? _arxivId(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segs = uri.pathSegments;
    final idx = segs.contains('abs') ? segs.indexOf('abs') : segs.indexOf('pdf');
    if (idx >= 0 && idx + 1 < segs.length) return segs.sublist(idx + 1).join('/');
    return null;
  }

  Future<void> _openItem(RecommendationItem item) async {
    if (!item.read) {
      context.read<AppProvider>().markRecommendationRead(item.contentId);
    }

    // arXiv papers: open in-app reader
    if (item.source == 'arxiv') {
      final aid = _arxivId(item.url);
      if (aid != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PaperReaderScreen(arxivId: aid, title: item.title),
        ));
        return;
      }
    }

    // Other sources: open in browser
    final url = item.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('该内容没有链接'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(12),
      ));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('无法打开链接: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  Future<void> _refreshRecommendations() async {
    try {
      await context.read<AppProvider>().refreshRecommendations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('推荐已更新'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('刷新失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  Future<void> _saveItem(RecommendationItem item) async {
    try {
      await context.read<AppProvider>().saveRecommendation(item.contentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('已收藏'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('收藏失败: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }
}

class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback? onRead; // non-null for arXiv items

  const _RecommendationCard({
    required this.item,
    required this.onOpen,
    required this.onSave,
    this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (sourceIcon, sourceColor) = switch (item.source) {
      'arxiv'         => (Icons.article_rounded,          const Color(0xFFB91C1C)),
      'github'        => (Icons.code_rounded,              const Color(0xFF1D4ED8)),
      'huggingface'   => (Icons.smart_toy_rounded,         const Color(0xFFFF6B00)),
      'csdn'          => (Icons.web_rounded,               const Color(0xFFFC5531)),
      'stackoverflow' => (Icons.question_answer_rounded,   const Color(0xFFF48024)),
      _               => (Icons.link_rounded,              cs.primary),
    };

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
        onTap: onOpen, // always tappable
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Source badge + read/saved icons ──────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sourceIcon, size: 12, color: sourceColor),
                        const SizedBox(width: 3),
                        Text(item.source.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sourceColor)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (item.read)
                    Icon(Icons.check_circle_rounded, size: 16, color: cs.outline),
                  if (item.saved)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.bookmark_rounded, size: 16, color: cs.tertiary),
                    ),
                ],
              ),

              // ── Title ─────────────────────────────────────────────────────
              const SizedBox(height: 8),
              Text(item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: item.read ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),

              // ── Description ───────────────────────────────────────────────
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.description!,
                    style: TextStyle(fontSize: 12, color: cs.outline),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],

              // ── Author / date / bookmark ──────────────────────────────────
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.author != null && item.author!.isNotEmpty) ...[
                    Icon(Icons.person_outline_rounded, size: 13, color: cs.outline),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(item.author!,
                          style: TextStyle(fontSize: 11, color: cs.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.publishedDate != null && item.publishedDate!.isNotEmpty) ...[
                    Icon(Icons.calendar_today_outlined, size: 12, color: cs.outline),
                    const SizedBox(width: 3),
                    Text(item.publishedDate!,
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                  const Spacer(),
                  if (onRead != null) ...[
                    FilledButton.tonal(
                      onPressed: onRead,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 13),
                          SizedBox(width: 4),
                          Text('阅读论文'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!item.saved)
                    IconButton(
                      onPressed: onSave,
                      icon: Icon(Icons.bookmark_outline_rounded,
                          size: 18, color: cs.tertiary),
                      tooltip: '收藏',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),

              // ── Tags ──────────────────────────────────────────────────────
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: item.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tag,
                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
