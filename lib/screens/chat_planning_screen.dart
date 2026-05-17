import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class ChatPlanningScreen extends StatefulWidget {
  const ChatPlanningScreen({super.key});

  @override
  State<ChatPlanningScreen> createState() => _ChatPlanningScreenState();
}

class _ChatPlanningScreenState extends State<ChatPlanningScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastFailed;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _lastFailed = null;
    _scrollToBottom();
    try {
      await context.read<AppProvider>().sendChatMessage(text);
      _scrollToBottom();
    } catch (e) {
      _lastFailed = text;
      if (!mounted) return;
      _showError('$e', retry: () {
        if (_lastFailed != null) {
          _msgCtrl.text = _lastFailed!;
          _send();
        }
      });
    }
  }

  Future<void> _createDraft() async {
    try {
      await context.read<AppProvider>().createDraft('确认规划方案');
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showError('$e', retry: _createDraft);
    }
  }

  Future<void> _confirmDraft(bool confirm) async {
    try {
      await context.read<AppProvider>().confirmDraft(confirm);
      if (!mounted) return;
      if (confirm) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('规划已导入日程表 ✓'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ));
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    }
  }

  void _showHistory(BuildContext context) {
    final messages = context.read<AppProvider>().chatHistory;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('当前没有对话记录'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HistorySheet(messages: messages),
    );
  }

  void _showError(String msg, {VoidCallback? retry}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 6),
        action: retry != null
            ? SnackBarAction(label: '重试', onPressed: retry)
            : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _AiAvatar(size: 32),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 规划助手',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('随时为你安排日程',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '历史记录',
            onPressed: () => _showHistory(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: '清空对话',
            onPressed: () => context.read<AppProvider>().clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, provider, __) {
                final messages = provider.chatHistory;
                final loading = provider.chatLoading;
                final draft = provider.currentDraft;

                if (messages.isEmpty && !loading) {
                  return _EmptyState();
                }

                // Build the items in display order (oldest→newest top→bottom),
                // then reverse both list and ListView so newest is always
                // anchored at the bottom — exactly like Claude / iMessage.
                final items = <Widget>[
                  for (int i = 0; i < messages.length; i++)
                    _Bubble(
                      message: messages[i],
                      showAvatar: i == 0 ||
                          messages[i].role != messages[i - 1].role,
                    ),
                  if (loading) _TypingBubble(),
                  if (draft != null)
                    _DraftCard(draft: draft, onConfirm: _confirmDraft),
                ];

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  itemCount: items.length,
                  itemBuilder: (_, i) => items[items.length - 1 - i],
                );
              },
            ),
          ),
          _InputBar(
            controller: _msgCtrl,
            onSend: _send,
            onDraft: _createDraft,
            onCancel: () => context.read<AppProvider>().cancelChatRequest(),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  final double size;
  const _AiAvatar({this.size = 36});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome_rounded,
          size: size * 0.5, color: Colors.white),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> _suggestions = const [
    '帮我规划一个2周的Python学习计划',
    '我明天有很多事，帮我安排一下',
    '每周一三五跑步30分钟',
    '月底前完成论文初稿',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _AiAvatar(size: 72),
        const SizedBox(height: 16),
        Text('你好，我是 AI 规划助手',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('告诉我你想做什么，我来帮你安排',
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13)),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions.map((s) {
            return ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                final provider =
                    context.read<AppProvider>();
                provider.sendChatMessage(s);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const _Bubble({required this.message, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == ChatMessageRole.user;
    final maxW = MediaQuery.sizeOf(context).width * 0.72;

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 12 : 3,
        bottom: 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isUser
            ? [_userBubble(context, cs, maxW)]
            : [
                // Avatar
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: showAvatar
                      ? _AiAvatar(size: 30)
                      : const SizedBox(width: 30),
                ),
                _aiBubble(context, cs, maxW),
              ],
      ),
    );
  }

  Widget _userBubble(BuildContext ctx, ColorScheme cs, double maxW) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: MarkdownBody(
        data: message.content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(ctx)).copyWith(
          p: TextStyle(color: cs.onPrimary, fontSize: 14.5, height: 1.45),
          strong: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
          em: TextStyle(color: cs.onPrimary, fontStyle: FontStyle.italic),
          code: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85),
              fontFamily: 'monospace', fontSize: 13),
          listBullet: TextStyle(color: cs.onPrimary),
          h1: TextStyle(color: cs.onPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          h2: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          h3: TextStyle(color: cs.onPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _aiBubble(BuildContext ctx, ColorScheme cs, double maxW) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: MarkdownBody(
        data: message.content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(ctx)).copyWith(
          p: TextStyle(color: cs.onSurface, fontSize: 14.5, height: 1.45),
          strong: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
          em: TextStyle(color: cs.onSurface, fontStyle: FontStyle.italic),
          code: TextStyle(color: cs.primary, fontFamily: 'monospace', fontSize: 13,
              backgroundColor: cs.surfaceContainerHighest),
          codeblockDecoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8)),
          listBullet: TextStyle(color: cs.onSurface),
          h1: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
          h2: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
          h3: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: _AiAvatar(size: 30),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3;
                  final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
                  final y = t < 0.5 ? t * 2 : (1 - t) * 2;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.translate(
                      offset: Offset(0, -4 * y),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cs.outline.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draft card ────────────────────────────────────────────────────────────────

class _DraftCard extends StatelessWidget {
  final ChatDraft draft;
  final void Function(bool) onConfirm;

  const _DraftCard({required this.draft, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AiAvatar(size: 30),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.assignment_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('规划草稿',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  if (draft.proposedEvents.isNotEmpty) ...[
                    _Section(
                        icon: Icons.calendar_month_rounded,
                        label: '日程 (${draft.proposedEvents.length})',
                        color: cs.primary),
                    ...draft.proposedEvents.map((e) => _ItemRow(
                          icon: Icons.schedule_rounded,
                          color: cs.primary,
                          text:
                              '${e.title}  ${e.date ?? ''} ${e.time ?? ''}',
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (draft.proposedTodos.isNotEmpty) ...[
                    _Section(
                        icon: Icons.checklist_rounded,
                        label: '待办 (${draft.proposedTodos.length})',
                        color: const Color(0xFFF97316)),
                    ...draft.proposedTodos.map((t) => _ItemRow(
                          icon: Icons.circle_outlined,
                          color: const Color(0xFFF97316),
                          text:
                              '${t.title}  ${t.deadline ?? ''}',
                        )),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onConfirm(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(color: cs.error),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onConfirm(true),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E)),
                          child: const Text('导入日程'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Section(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ItemRow(
      {required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 3),
      child: Row(children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color:
                        Theme.of(context).colorScheme.onSurface))),
      ]),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onDraft;
  final VoidCallback onCancel;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onDraft,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        final loading = provider.chatLoading;
        final hasSession = provider.currentSessionId != null;
        final hasDraft = provider.currentDraft != null;

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('AI 正在思考…',
                          style: TextStyle(
                              fontSize: 12, color: cs.outline)),
                      const Spacer(),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          minimumSize: Size.zero,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('取消',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasSession && !hasDraft)
                      Tooltip(
                        message: '生成规划草稿',
                        child: IconButton(
                          onPressed: loading ? null : onDraft,
                          icon: Icon(Icons.auto_fix_high_rounded,
                              color: cs.tertiary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: controller,
                          enabled: !loading,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          style: const TextStyle(fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: '输入你的规划需求…',
                            hintStyle: TextStyle(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 14.5),
                            filled: false,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: loading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 40,
                              height: 40,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5),
                              ),
                            )
                          : IconButton.filled(
                              key: const ValueKey('send'),
                              onPressed: onSend,
                              icon: const Icon(Icons.send_rounded,
                                  size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                fixedSize: const Size(40, 40),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── History sheet ─────────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final List<ChatMessage> messages;
  const _HistorySheet({required this.messages});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text('对话记录 (${messages.length}条)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isUser = msg.role == ChatMessageRole.user;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!isUser) ...[
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [cs.primary, cs.tertiary]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isUser ? cs.primary : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                        ),
                        child: MarkdownBody(
                          data: msg.content,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                                  Theme.of(context))
                              .copyWith(
                            p: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isUser ? cs.onPrimary : cs.onSurface),
                          ),
                        ),
                      ),
                    ),
                    if (isUser) const SizedBox(width: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
