class ScheduleEvent {
  final int? id;
  final String title;
  final String? date;
  final String? time;
  final String? location;
  final String? notes;
  final DateTime createdAt;

  const ScheduleEvent({
    this.id,
    required this.title,
    this.date,
    this.time,
    this.location,
    this.notes,
    required this.createdAt,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    return ScheduleEvent(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      date: json['date'] as String?,
      time: json['time'] as String?,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'date': date,
        'time': time,
        'location': location,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'title': title,
        'date': date,
        'time': time,
        'location': location,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory ScheduleEvent.fromDbMap(Map<String, dynamic> map) {
    return ScheduleEvent(
      id: map['id'] as int?,
      title: map['title'] as String,
      date: map['date'] as String?,
      time: map['time'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ScheduleEvent copyWith({
    int? id,
    String? title,
    String? date,
    String? time,
    String? location,
    String? notes,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

enum TodoPriority { low, medium, high }

class Todo {
  final int? id;
  final String title;
  final String? deadline;
  final TodoPriority priority;
  final String? notes;
  final bool isDone;
  final DateTime createdAt;

  const Todo({
    this.id,
    required this.title,
    this.deadline,
    this.priority = TodoPriority.medium,
    this.notes,
    this.isDone = false,
    required this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      deadline: json['deadline'] as String?,
      priority: _parsePriority(json['priority'] as String?),
      notes: json['notes'] as String?,
      isDone: (json['is_done'] as int?) == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static TodoPriority _parsePriority(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return TodoPriority.high;
      case 'low':
        return TodoPriority.low;
      default:
        return TodoPriority.medium;
    }
  }

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'title': title,
        'deadline': deadline,
        'priority': priority.name,
        'notes': notes,
        'is_done': isDone ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Todo.fromDbMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      deadline: map['deadline'] as String?,
      priority: _parsePriority(map['priority'] as String?),
      notes: map['notes'] as String?,
      isDone: (map['is_done'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'deadline': deadline,
        'priority': priority.name,
        'notes': notes,
        'is_done': isDone,
        'created_at': createdAt.toIso8601String(),
      };

  Todo copyWith({
    int? id,
    String? title,
    String? deadline,
    TodoPriority? priority,
    String? notes,
    bool? isDone,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }
}

class ExtractionResult {
  final List<ScheduleEvent> events;
  final List<Todo> todos;

  const ExtractionResult({
    required this.events,
    required this.todos,
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    return ExtractionResult(
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => ScheduleEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      todos: (json['todos'] as List<dynamic>? ?? [])
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty => events.isEmpty && todos.isEmpty;
  int get totalCount => events.length + todos.length;
}
