import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 44,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '还没有内容',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '前往输入页提取日程或待办事项',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
          ),
        ],
      ),
    );
  }
}
