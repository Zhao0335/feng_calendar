import 'package:flutter/material.dart';
import '../models/models.dart';

// ─── Edit Event ───────────────────────────────────────────────────────────────

Future<ScheduleEvent?> showEditEventSheet(
    BuildContext context, ScheduleEvent event) {
  return showModalBottomSheet<ScheduleEvent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditEventSheet(event: event),
  );
}

class _EditEventSheet extends StatefulWidget {
  final ScheduleEvent event;
  const _EditEventSheet({required this.event});

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _date = TextEditingController(text: widget.event.date ?? '');
    _time = TextEditingController(text: widget.event.time ?? '');
    _location = TextEditingController(text: widget.event.location ?? '');
    _notes = TextEditingController(text: widget.event.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _time.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_date.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_date.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_time.text.isNotEmpty) {
      final parts = _time.text.split(':');
      if (parts.length == 2) {
        initial = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.event.copyWith(
      title: _title.text.trim(),
      date: _date.text.trim().isEmpty ? null : _date.text.trim(),
      time: _time.text.trim().isEmpty ? null : _time.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              const SizedBox(height: 8),
              Text('编辑日程',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '标题 *',
                    prefixIcon: Icon(Icons.title_rounded, size: 20)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '标题不能为空' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _date,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: InputDecoration(
                      labelText: '日期',
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 18),
                      suffixIcon: _date.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _date.clear()),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _time,
                    readOnly: true,
                    onTap: _pickTime,
                    decoration: InputDecoration(
                      labelText: '时间',
                      prefixIcon:
                          const Icon(Icons.access_time_rounded, size: 18),
                      suffixIcon: _time.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _time.clear()),
                            )
                          : null,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                    labelText: '地点',
                    prefixIcon:
                        Icon(Icons.location_on_rounded, size: 20)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: '备注',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded, size: 20)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('保存',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Todo ────────────────────────────────────────────────────────────────

Future<Todo?> showEditTodoSheet(BuildContext context, Todo todo) {
  return showModalBottomSheet<Todo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditTodoSheet(todo: todo),
  );
}

class _EditTodoSheet extends StatefulWidget {
  final Todo todo;
  const _EditTodoSheet({required this.todo});

  @override
  State<_EditTodoSheet> createState() => _EditTodoSheetState();
}

class _EditTodoSheetState extends State<_EditTodoSheet> {
  late final TextEditingController _title;
  late final TextEditingController _deadline;
  late final TextEditingController _notes;
  late TodoPriority _priority;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.todo.title);
    _deadline = TextEditingController(text: widget.todo.deadline ?? '');
    _notes = TextEditingController(text: widget.todo.notes ?? '');
    _priority = widget.todo.priority;
  }

  @override
  void dispose() {
    _title.dispose();
    _deadline.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    DateTime initial = DateTime.now();
    if (_deadline.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_deadline.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _deadline.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.todo.copyWith(
      title: _title.text.trim(),
      deadline:
          _deadline.text.trim().isEmpty ? null : _deadline.text.trim(),
      priority: _priority,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              const SizedBox(height: 8),
              Text('编辑待办',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '标题 *',
                    prefixIcon: Icon(Icons.check_circle_outline, size: 20)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '标题不能为空' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deadline,
                readOnly: true,
                onTap: _pickDeadline,
                decoration: InputDecoration(
                  labelText: '截止日期',
                  prefixIcon:
                      const Icon(Icons.event_rounded, size: 18),
                  suffixIcon: _deadline.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _deadline.clear()),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text('优先级',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<TodoPriority>(
                segments: const [
                  ButtonSegment(
                      value: TodoPriority.low,
                      label: Text('低'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 14)),
                  ButtonSegment(
                      value: TodoPriority.medium,
                      label: Text('中'),
                      icon: Icon(Icons.remove_rounded, size: 14)),
                  ButtonSegment(
                      value: TodoPriority.high,
                      label: Text('高'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 14)),
                ],
                selected: {_priority},
                onSelectionChanged: (s) =>
                    setState(() => _priority = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: '备注',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded, size: 20)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('保存',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
