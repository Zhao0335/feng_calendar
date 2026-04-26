import 'package:flutter/material.dart';
import '../models/models.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onPin;

  const TodoCard({
    super.key,
    required this.todo,
    this.onToggle,
    this.onDelete,
    this.onTap,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = todo.isDone;
    final priorityColor = switch (todo.priority) {
      TodoPriority.high => const Color(0xFFEF4444),
      TodoPriority.medium => const Color(0xFFF97316),
      TodoPriority.low => const Color(0xFF94A3B8),
    };

    return Opacity(
      opacity: isDone ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: (onDelete != null || onPin != null)
            ? () => _showActionSheet(context)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: todo.isPinned
                ? Border.all(color: const Color(0xFFEF4444), width: 1.8)
                : null,
            boxShadow: [
              BoxShadow(
                color: todo.isPinned
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : cs.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: priorityColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Checkbox(
                            value: isDone,
                            onChanged: onToggle != null
                                ? (v) => onToggle!(v ?? false)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  if (todo.isPinned) ...[
                                    Icon(Icons.push_pin_rounded,
                                        size: 12,
                                        color: priorityColor
                                            .withValues(alpha: 0.7)),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      todo.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationThickness: 2,
                                            height: 1.3,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (todo.notes != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  todo.notes!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (todo.deadline != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              todo.deadline!,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (onPin != null)
              ListTile(
                leading: Icon(todo.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded),
                title: Text(todo.isPinned ? '取消置顶' : '置顶'),
                onTap: () {
                  Navigator.pop(context);
                  onPin!();
                },
              ),
            if (onTap != null)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('编辑'),
                onTap: () {
                  Navigator.pop(context);
                  onTap!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded,
                    color: Color(0xFFEF4444)),
                title: const Text('删除',
                    style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确认删除「${todo.title}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onDelete?.call();
              },
              child: const Text('删除')),
        ],
      ),
    );
  }
}
