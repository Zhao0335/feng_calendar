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
      final text = _textController.text.trim();
      if (text.isEmpty) return;
      success = await provider.extractFromText(text);
      if (success) _textController.clear();
    }

    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    if (!success) {
      _showSnack(provider.errorMessage ?? '提取失败，请检查服务器连接',
          color: cs.error);
    } else {
      final ec = provider.events.length;
      final tc = provider.todos.length;
      final msg = (ec == 0 && tc == 0)
          ? '未提取到任何内容'
          : '提取完成：${[
              if (ec > 0) '$ec 个日程',
              if (tc > 0) '$tc 个待办',
            ].join('、')}';
      _showSnack(msg,
          color: (ec == 0 && tc == 0)
              ? cs.error
              : const Color(0xFF22C55E));
    }
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
        actions: _planMode && provider.currentSessionId != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: '清空对话',
                  onPressed: () {
                    provider.clearChat();
                    setState(() {});
                  },
                ),
              ]
            : null,
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

  // ── Extract content area ──────────────────────────────────────────────────

  Widget _buildExtractArea(ColorScheme cs) {
    if (_attachment != null) {
      return _isImage ? _buildImagePreview(cs) : _buildFilePreview(cs);
    }
    return _buildExtractHint(cs);
  }

  Widget _buildExtractHint(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
            const SizedBox(height: 20),
            Text(
              '输入文字或添加附件',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '支持文字描述、截图、PDF / TXT 文件\n提取完成后自动保存到日程列表',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme cs) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_attachment!, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: _ClearButton(onTap: _clearAttachment),
        ),
      ],
    );
  }

  Widget _buildFilePreview(ColorScheme cs) {
    return Stack(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.18), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _attachmentType == 'pdf'
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_rounded,
                  size: 60,
                  color: cs.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  _attachmentName ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _attachmentType?.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: _ClearButton(onTap: _clearAttachment),
        ),
      ],
    );
  }

  // ── Plan / Chat content area ──────────────────────────────────────────────

  Widget _buildChatArea(ColorScheme cs, AppProvider provider) {
    final messages = provider.chatHistory;
    final draft = provider.currentDraft;

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_alt_rounded,
                    size: 38, color: cs.secondary),
              ),
              const SizedBox(height: 20),
              Text(
                '告诉 AI 你的规划需求',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '例如：我想在 2 周内学完 Python 基础',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: messages.length + (draft != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return _buildMessageBubble(messages[index], cs);
        }
        return _buildDraftCard(draft!, cs);
      },
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
          child: Text(
            message.content,
            style: TextStyle(color: cs.onPrimary, fontSize: 14, height: 1.5),
          ),
        ),
      );
    }

    // AI bubble: render Markdown
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(fontSize: 14, height: 1.6, color: cs.onSurface),
            strong: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface),
            em: TextStyle(
                fontStyle: FontStyle.italic, color: cs.onSurface),
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
              border: Border(
                  left: BorderSide(color: cs.primary, width: 3)),
              color: cs.primaryContainer.withValues(alpha: 0.2),
            ),
            listBullet:
                TextStyle(fontSize: 14, color: cs.onSurface),
            h1: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface),
            h2: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface),
            h3: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
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
