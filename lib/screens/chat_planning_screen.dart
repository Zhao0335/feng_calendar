import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class ChatPlanningScreen extends StatefulWidget {
  const ChatPlanningScreen({super.key});

  @override
  State<ChatPlanningScreen> createState() => _ChatPlanningScreenState();
}

class _ChatPlanningScreenState extends State<ChatPlanningScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastFailedMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _lastFailedMessage = null;

    final provider = context.read<AppProvider>();
    try {
      await provider.sendChatMessage(text);
      _scrollToBottom();
    } catch (e) {
      _lastFailedMessage = text;
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '重试',
          onPressed: () {
            if (_lastFailedMessage != null) {
              _messageController.text = _lastFailedMessage!;
              _sendMessage();
            }
          },
        ),
      ));
    }
  }

  void _cancelRequest() {
    final provider = context.read<AppProvider>();
    provider.cancelChatRequest();
  }

  Future<void> _createDraft() async {
    final provider = context.read<AppProvider>();
    try {
      await provider.createDraft('确认规划方案');
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '重试',
          onPressed: _createDraft,
        ),
      ));
    }
  }

  Future<void> _confirmDraft(bool confirm) async {
    final provider = context.read<AppProvider>();
    try {
      await provider.confirmDraft(confirm);
      if (!mounted) return;
      if (confirm) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('规划已导入日程表'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 规划助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '清空对话',
            onPressed: () {
              context.read<AppProvider>().clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, provider, __) {
                final messages = provider.chatHistory;
                if (messages.isEmpty) {
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
                          child: Icon(Icons.auto_awesome_rounded,
                              size: 36, color: cs.primary),
                        ),
                        const SizedBox(height: 16),
                        Text('告诉 AI 你的规划需求',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: cs.onSurface)),
                        const SizedBox(height: 6),
                        Text('例如：我想在2周内学习完Python基础',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.outline)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount:
                      messages.length + (provider.currentDraft != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return _buildMessageBubble(messages[index], cs);
                    }
                    return _buildDraftCard(provider.currentDraft!, cs);
                  },
                );
              },
            ),
          ),
          _buildInputArea(cs),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ColorScheme cs) {
    final isUser = message.role == ChatMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? cs.onPrimary : cs.onSurface,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(ChatDraft draft, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 18, color: cs.tertiary),
              const SizedBox(width: 6),
              Text('规划草稿',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.tertiary,
                    fontSize: 14,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (draft.proposedEvents.isNotEmpty) ...[
            Text('日程 (${draft.proposedEvents.length})',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontSize: 13)),
            const SizedBox(height: 4),
            ...draft.proposedEvents.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('${e.title}  ${e.date ?? ''} ${e.time ?? ''}',
                          style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (draft.proposedTodos.isNotEmpty) ...[
            Text('待办 (${draft.proposedTodos.length})',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontSize: 13)),
            const SizedBox(height: 4),
            ...draft.proposedTodos.map((t) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: cs.tertiary),
                      const SizedBox(width: 6),
                      Text('${t.title}  ${t.deadline ?? ''}',
                          style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _confirmDraft(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _confirmDraft(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('导入日程'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ColorScheme cs) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        final isLoading = provider.chatLoading;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.primary),
                        ),
                        const SizedBox(width: 8),
                        Text('AI 正在思考...',
                            style: TextStyle(
                                fontSize: 12, color: cs.outline)),
                        const Spacer(),
                        TextButton(
                          onPressed: _cancelRequest,
                          style: TextButton.styleFrom(
                            foregroundColor: cs.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('取消', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (provider.currentSessionId != null &&
                        provider.currentDraft == null)
                      IconButton(
                        onPressed: isLoading ? null : _createDraft,
                        icon: Icon(Icons.assignment_outlined,
                            color: cs.tertiary, size: 22),
                        tooltip: '生成草稿',
                      ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !isLoading,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: '输入您的规划需求...',
                          hintStyle: TextStyle(color: cs.outline, fontSize: 14),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: cs.primary),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
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
