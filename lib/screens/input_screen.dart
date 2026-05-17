import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // ── Extract mode state ────────────────────────────────────────────────────
  File? _attachment;
  String? _attachmentType;
  String? _attachmentName;
  bool _isImage = false;

  // ── Extract chat history (local, per-session) ─────────────────────────────
  final _extractHistory = <_Msg>[];

  // ── Mode ──────────────────────────────────────────────────────────────────
  bool _planMode = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = context.read<AppProvider>().pendingFilePath;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyPendingFile(pending);
          context.read<AppProvider>().clearPendingFile();
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────

  void _togglePlanMode() {
    final provider = context.read<AppProvider>();
    setState(() {
      _planMode = !_planMode;
      if (_planMode) {
        _clearAttachment();
        _textController.clear();
      } else {
        provider.clearChat();
        _textController.clear();
      }
    });
  }

  // ── Extract helpers ───────────────────────────────────────────────────────

  void _applyPendingFile(String path) {
    final name = path.split('/').last;
    final ext = name.split('.').last.toLowerCase();
    setState(() {
      _attachment = File(path);
      _attachmentType = ext == 'md' ? 'txt' : ext;
      _attachmentName = name;
      _isImage = false;
      _textController.clear();
    });
  }

  void _clearAttachment() {
    setState(() {
      _attachment = null;
      _attachmentType = null;
      _attachmentName = null;
      _isImage = false;
    });
  }

  Future<void> _showAttachmentPicker() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image_rounded, color: cs.primary),
                ),
                title: const Text('从相册选择图片'),
                subtitle: Text('JPG · PNG',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.attach_file_rounded, color: cs.tertiary),
                ),
                title: const Text('选择文件'),
                subtitle: Text('PDF · TXT · MD',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final xfile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile != null && mounted) {
      setState(() {
        _attachment = File(xfile.path);
        _attachmentType = 'image';
        _attachmentName = xfile.name;
        _isImage = true;
        _textController.clear();
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (result != null && result.files.single.path != null && mounted) {
      final file = result.files.single;
      final ext = file.path!.split('.').last.toLowerCase();
      setState(() {
        _attachment = File(file.path!);
        _attachmentType = ext == 'md' ? 'txt' : ext;
        _attachmentName = file.name;
        _isImage = false;
        _textController.clear();
      });
    }
  }

  Future<void> _extract() async {
    final provider = context.read<AppProvider>();

    // Build user bubble text
    final String userText;
    if (_attachment != null) {
      if (_isImage) {
        userText = '[图片] ${_attachmentName ?? ""}';
      } else {
        userText = '[文件] ${_attachmentName ?? ""}';
      }
    } else {
      userText = _textController.text.trim();
      if (userText.isEmpty) return;
    }

    // Add user bubble immediately
    setState(() => _extractHistory.add(_Msg(isUser: true, text: userText)));
    _textController.clear();

    bool success = false;
    if (_attachment != null) {
      if (_isImage) {
        success = await provider.extractFromImage(_attachment!);
      } else {
        success = await provider.extractFromFile(
            _attachment!, _attachmentType ?? 'txt');
      }
      if (success) _clearAttachment();
    } else {
      success = await provider.extractFromText(userText);
    }

    if (!mounted) return;

    final aiReply = success
        ? (provider.lastExtractMessage?.isNotEmpty == true
            ? provider.lastExtractMessage!
            : '提取完成：${provider.events.length} 个日程、${provider.todos.length} 个待办')
        : (provider.errorMessage ?? '提取失败，请检查服务器连接');

    setState(() => _extractHistory.add(_Msg(isUser: false, text: aiReply)));
  }

  // ── Plan helpers ──────────────────────────────────────────────────────────

  Future<void> _sendChatMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final provider = context.read<AppProvider>();
    try {
      await provider.sendChatMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    }
  }

  Future<void> _createDraft() async {
    final provider = context.read<AppProvider>();
    try {
      await provider.createDraft('确认规划方案');
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    }
  }

  Future<void> _confirmDraft(bool confirm) async {
    final provider = context.read<AppProvider>();
    try {
      await provider.confirmDraft(confirm);
      if (!mounted) return;
      if (confirm) {
        _showSnack('规划已导入日程表', color: const Color(0xFF22C55E));
        setState(() => _planMode = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    }
  }

  void _showChatHistory(List<ChatMessage> messages) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChatHistorySheet(messages: messages),
    );
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

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  bool get _canSend {
    if (_planMode) return _textController.text.trim().isNotEmpty;
    if (_attachment != null) return true;
    return _textController.text.trim().isNotEmpty;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final isExtracting =
        provider.status == ExtractionStatus.loading;
    final isChatLoading = provider.chatLoading;
    final isLoading = _planMode ? isChatLoading : isExtracting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_planMode ? 'AI 规划' : '提取日程'),
        actions: [
          if (_planMode && provider.chatHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: '历史记录',
              onPressed: () => _showChatHistory(provider.chatHistory),
            ),
          if (_planMode && provider.currentSessionId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '清空对话',
              onPressed: () {
                provider.clearChat();
                setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _planMode
                ? _buildChatArea(cs, provider)
                : _buildExtractArea(cs),
          ),
          _buildInputBar(cs, isLoading, provider),
        ],
      ),
    );
  }

  // ── Extract chat area ─────────────────────────────────────────────────────

  Widget _buildExtractArea(ColorScheme cs) {
    final isLoading = context.watch<AppProvider>().status == ExtractionStatus.loading;

    if (_extractHistory.isEmpty) {
      // Empty state as AI welcome bubble at bottom
      return ListView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [_aiBubble(cs, '你好！把想记录的日程发给我吧。\n支持文字描述、截图、PDF / TXT 文件。')],
      );
    }

    final items = <Widget>[
      for (final msg in _extractHistory)
        msg.isUser ? _userBubble(cs, msg.text) : _aiBubble(cs, msg.text),
      if (isLoading) _typingBubble(cs),
    ];

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length,
      itemBuilder: (_, i) => items[items.length - 1 - i],
    );
  }

  // ── Shared bubble builders ────────────────────────────────────────────────

  Widget _userBubble(ColorScheme cs, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
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
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
      ),
    );
  }

  Widget _aiBubble(ColorScheme cs, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SmallAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(text,
                  style: TextStyle(
                      color: cs.onSurface, fontSize: 14.5, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SmallAvatar(),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(delay: 0),
              _Dot(delay: 200),
              _Dot(delay: 400),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Plan / Chat content area ──────────────────────────────────────────────

  Widget _buildChatArea(ColorScheme cs, AppProvider provider) {
    final messages = provider.chatHistory;
    final draft = provider.currentDraft;
    final loading = provider.chatLoading;

    if (messages.isEmpty && !loading) {
      return ListView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [_aiBubble(cs, '告诉我你的规划需求吧，例如：\n我想在 2 周内学完 Python 基础')],
      );
    }

    final items = <Widget>[
      for (final msg in messages) _buildMessageBubble(msg, cs),
      if (loading) _typingBubble(cs),
      if (draft != null) _buildDraftCard(draft, cs),
    ];

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length,
      itemBuilder: (_, i) => items[items.length - 1 - i],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ColorScheme cs) {
    final isUser = message.role == ChatMessageRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
        ),
      );
    }

    // AI bubble: avatar + Markdown
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SmallAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
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
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(fontSize: 14, height: 1.6, color: cs.onSurface),
                  strong: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                  em: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurface),
                  code: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(left: BorderSide(color: cs.primary, width: 3)),
                    color: cs.primaryContainer.withValues(alpha: 0.2),
                  ),
                  listBullet: TextStyle(fontSize: 14, color: cs.onSurface),
                  h1: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
                  h2: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                  h3: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
              ),
            ),
          ),
        ],
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
                      fontSize: 14)),
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
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${e.title}  ${e.date ?? ''} ${e.time ?? ''}'
                              .trim(),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface)),
                    ),
                  ]),
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
                  child: Row(children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 13, color: cs.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${t.title}  ${t.deadline ?? ''}'.trim(),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface)),
                    ),
                  ]),
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

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(
      ColorScheme cs, bool isLoading, AppProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chat loading indicator
              if (_planMode && isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.secondary),
                    ),
                    const SizedBox(width: 8),
                    Text('AI 正在思考…',
                        style:
                            TextStyle(fontSize: 12, color: cs.outline)),
                    const Spacer(),
                    TextButton(
                      onPressed: provider.cancelChatRequest,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
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
                  // Attachment button (extract mode only)
                  if (!_planMode)
                    _AttachButton(
                      onTap: isLoading ? null : _showAttachmentPicker,
                      cs: cs,
                    ),
                  if (!_planMode) const SizedBox(width: 6),

                  // Plan mode toggle
                  _PlanToggleButton(
                    active: _planMode,
                    onTap: isLoading ? null : _togglePlanMode,
                    cs: cs,
                  ),
                  const SizedBox(width: 6),

                  // Text input
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: TextField(
                        controller: _textController,
                        enabled: !isLoading &&
                            (_planMode || _attachment == null),
                        maxLines: null,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _planMode
                              ? '描述你的规划需求…'
                              : _attachment != null
                                  ? '已添加附件，点击 ↑ 开始提取'
                                  : '输入文字内容…',
                          hintStyle: TextStyle(
                              color: cs.outline, fontSize: 14),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color:
                                    cs.primary.withValues(alpha: 0.5),
                                width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Draft button (plan mode, session active, no draft yet)
                  if (_planMode &&
                      provider.currentSessionId != null &&
                      provider.currentDraft == null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _IconBtn(
                        icon: Icons.assignment_outlined,
                        color: cs.tertiary,
                        tooltip: '生成草稿',
                        onTap: isLoading ? null : _createDraft,
                      ),
                    ),

                  // Send button
                  _SendButton(
                    canSend: _canSend && !isLoading,
                    isLoading: isLoading,
                    onTap: _planMode ? _sendChatMessage : _extract,
                    cs: cs,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final VoidCallback? onTap;
  final ColorScheme cs;
  const _AttachButton({required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.add_rounded,
              color: onTap == null ? cs.outline : cs.onSurface, size: 24),
        ),
      ),
    );
  }
}

class _PlanToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  final ColorScheme cs;
  const _PlanToggleButton(
      {required this.active, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? cs.secondary : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.psychology_alt_rounded,
            color: active
                ? cs.onSecondary
                : (onTap == null ? cs.outline : cs.onSurfaceVariant),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool canSend;
  final bool isLoading;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _SendButton({
    required this.canSend,
    required this.isLoading,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: canSend ? cs.primary : cs.surfaceContainerLow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: canSend ? onTap : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : Icon(Icons.arrow_upward_rounded,
                    color: canSend ? cs.onPrimary : cs.outline, size: 22),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                color: onTap == null ? cs.outline : color, size: 20),
          ),
        ),
      ),
    );
  }
}

// Simple message model for extract chat history
class _Msg {
  final bool isUser;
  final String text;
  const _Msg({required this.isUser, required this.text});
}

class _ChatHistorySheet extends StatelessWidget {
  final List<ChatMessage> messages;
  const _ChatHistorySheet({required this.messages});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Spacer(),
                Text('对话记录 (${messages.length}条)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
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
                          color: isUser
                              ? cs.primary
                              : cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isUser ? 16 : 4),
                            bottomRight:
                                Radius.circular(isUser ? 4 : 16),
                          ),
                        ),
                        child: MarkdownBody(
                          data: msg.content,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isUser
                                    ? cs.onPrimary
                                    : cs.onSurface),
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

class _SmallAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Interval(widget.delay / 900, (widget.delay + 400) / 900,
          curve: Curves.easeInOut),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: 0.4 + _anim.value * 0.5),
          shape: BoxShape.circle,
        ),
        transform: Matrix4.translationValues(0, -4 * _anim.value, 0),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface),
      ),
    );
  }
}
