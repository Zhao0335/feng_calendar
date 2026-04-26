import 'package:flutter/material.dart';
import '../models/models.dart';

class EventCard extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onPin;

  const EventCard({
    super.key,
    required this.event,
    this.onDelete,
    this.onTap,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBg =
        isDark ? cs.primaryContainer.withValues(alpha: 0.6) : cs.primaryContainer;
    final badgeFg = cs.onPrimaryContainer;

    return GestureDetector(
      onTap: onTap,
      onLongPress: (onDelete != null || onPin != null)
          ? () => _showActionSheet(context)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: event.isPinned
              ? Border.all(color: const Color(0xFFEF4444), width: 1.8)
              : null,
          boxShadow: [
            BoxShadow(
              color: event.isPinned
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
              Container(width: 4, color: cs.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (event.isPinned) ...[
                                  Icon(Icons.push_pin_rounded,
                                      size: 13,
                                      color: cs.primary
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (event.date != null || event.time != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      size: 11, color: badgeFg),
                                  const SizedBox(width: 3),
                                  Text(
                                    [
                                      if (event.date != null) event.date!,
                                      if (event.time != null) event.time!,
                                    ].join('  '),
                                    style: TextStyle(
                                      color: badgeFg,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 13, color: cs.outline),
                            const SizedBox(width: 3),
                            Text(
                              event.location!,
                              style: TextStyle(
                                color: cs.outline,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.notes != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          event.notes!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                leading: Icon(event.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded),
                title: Text(event.isPinned ? '取消置顶' : '置顶'),
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
        title: const Text('删除日程'),
        content: Text('确认删除「${event.title}」？'),
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
