import 'dart:convert';

bool _parseBool(dynamic v) {
  if (v is bool) return v;
  if (v is int) return v == 1;
  return false;
}

List<String> _parseStringList(dynamic v, List<String> fallback) {
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return fallback;
}

/// Parses a field that may be a JSON-encoded string or a proper List of Maps.
List<T> _parseObjectList<T>(
    dynamic v, T Function(Map<String, dynamic>) fromJson) {
  List<dynamic> list;
  if (v is List) {
    list = v;
  } else if (v is String) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) {
        list = decoded;
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  } else {
    return [];
  }
  return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
}

class ScheduleEvent {
  final int? id;
  final String title;
  final String? date;
  final String? time;
  final String? location;
  final String? notes;
  final bool isPinned;
  final DateTime createdAt;

  const ScheduleEvent({
    this.id,
    required this.title,
    this.date,
    this.time,
    this.location,
    this.notes,
    this.isPinned = false,
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
      isPinned: _parseBool(json['is_pinned']),
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
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'title': title,
        'date': date,
        'time': time,
        'location': location,
        'notes': notes,
        'is_pinned': isPinned ? 1 : 0,
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
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ScheduleEvent copyWith({
    int? id,
    String? title,
    Object? date = _sentinel,
    Object? time = _sentinel,
    Object? location = _sentinel,
    Object? notes = _sentinel,
    bool? isPinned,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date == _sentinel ? this.date : date as String?,
      time: time == _sentinel ? this.time : time as String?,
      location: location == _sentinel ? this.location : location as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      isPinned: isPinned ?? this.isPinned,
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
  final bool isPinned;
  final DateTime createdAt;

  const Todo({
    this.id,
    required this.title,
    this.deadline,
    this.priority = TodoPriority.medium,
    this.notes,
    this.isDone = false,
    this.isPinned = false,
    required this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      deadline: json['deadline'] as String?,
      priority: _parsePriority(json['priority'] as String?),
      notes: json['notes'] as String?,
      isDone: _parseBool(json['is_done']),
      isPinned: _parseBool(json['is_pinned']),
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
        'is_pinned': isPinned ? 1 : 0,
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
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
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
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  Todo copyWith({
    int? id,
    String? title,
    Object? deadline = _sentinel,
    TodoPriority? priority,
    Object? notes = _sentinel,
    bool? isDone,
    bool? isPinned,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      deadline: deadline == _sentinel ? this.deadline : deadline as String?,
      priority: priority ?? this.priority,
      notes: notes == _sentinel ? this.notes : notes as String?,
      isDone: isDone ?? this.isDone,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
    );
  }
}

// Sentinel for nullable copyWith fields
const Object _sentinel = Object();

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

enum ChatMessageRole { user, assistant }

class ChatMessage {
  final ChatMessageRole role;
  final String content;

  const ChatMessage({required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'user'
          ? ChatMessageRole.user
          : ChatMessageRole.assistant,
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role == ChatMessageRole.user ? 'user' : 'assistant',
        'content': content,
      };
}

class ProposedEvent {
  final String title;
  final String? date;
  final String? time;

  const ProposedEvent({required this.title, this.date, this.time});

  factory ProposedEvent.fromJson(Map<String, dynamic> json) {
    return ProposedEvent(
      title: json['title'] as String? ?? '',
      date: json['date'] as String?,
      time: json['time'] as String?,
    );
  }
}

class ProposedTodo {
  final String title;
  final String? deadline;
  final String? priority;

  const ProposedTodo({required this.title, this.deadline, this.priority});

  factory ProposedTodo.fromJson(Map<String, dynamic> json) {
    return ProposedTodo(
      title: json['title'] as String? ?? '',
      deadline: json['deadline'] as String?,
      priority: json['priority'] as String?,
    );
  }
}

class ChatDraft {
  final int id;
  final String title;
  final String? description;
  final List<ProposedEvent> proposedEvents;
  final List<ProposedTodo> proposedTodos;
  final String status;

  const ChatDraft({
    required this.id,
    required this.title,
    this.description,
    this.proposedEvents = const [],
    this.proposedTodos = const [],
    this.status = 'draft',
  });

  factory ChatDraft.fromJson(Map<String, dynamic> json) {
    return ChatDraft(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      proposedEvents: _parseObjectList(
          json['proposed_events'], ProposedEvent.fromJson),
      proposedTodos: _parseObjectList(
          json['proposed_todos'], ProposedTodo.fromJson),
      status: json['status'] as String? ?? 'draft',
    );
  }
}

class Interest {
  final int? id;
  final String category;
  final String tag;
  final List<String> keywords;
  final double weight;

  const Interest({
    this.id,
    required this.category,
    required this.tag,
    this.keywords = const [],
    this.weight = 1.0,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'] as int?,
      category: json['category'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      keywords: _parseStringList(json['keywords'], const []),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class RecommendationItem {
  final int id;
  final int contentId;
  final double score;
  final bool read;
  final bool saved;
  final String source;
  final String title;
  final String? description;
  final String? url;
  final String? author;
  final String? publishedDate;
  final String? contentType;
  final List<String> tags;

  const RecommendationItem({
    required this.id,
    required this.contentId,
    this.score = 0,
    this.read = false,
    this.saved = false,
    this.source = '',
    required this.title,
    this.description,
    this.url,
    this.author,
    this.publishedDate,
    this.contentType,
    this.tags = const [],
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      id: json['id'] as int,
      contentId: json['content_id'] as int? ?? json['id'] as int,
      score: (json['recommendation_score'] as num?)?.toDouble() ?? 0,
      read: (json['read'] as int?) == 1,
      saved: (json['saved'] as int?) == 1,
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      url: json['url'] as String?,
      author: json['author'] as String?,
      publishedDate: json['published_date'] as String?,
      contentType: json['content_type'] as String?,
      tags: _parseStringList(json['tags'], const []),
    );
  }
}

class ArxivReport {
  final int? id;
  final String? reportDate;
  final String? summary;
  final String? htmlContent;
  final int downloadCount;

  const ArxivReport({
    this.id,
    this.reportDate,
    this.summary,
    this.htmlContent,
    this.downloadCount = 0,
  });

  factory ArxivReport.fromJson(Map<String, dynamic> json) {
    return ArxivReport(
      id: json['id'] as int?,
      reportDate: json['report_date'] as String?,
      summary: json['summary'] as String?,
      htmlContent: json['html_content'] as String?,
      downloadCount: json['download_count'] as int? ?? 0,
    );
  }
}

class ArxivPreference {
  final String pushTime;
  final int paperCount;
  final List<String> categories;
  final bool isEnabled;

  const ArxivPreference({
    this.pushTime = '09:00',
    this.paperCount = 5,
    this.categories = const ['cs.AI', 'cs.LG'],
    this.isEnabled = true,
  });

  factory ArxivPreference.fromJson(Map<String, dynamic> json) {
    return ArxivPreference(
      pushTime: json['push_time'] as String? ?? '09:00',
      paperCount: json['paper_count'] as int? ?? 5,
      categories: _parseStringList(
          json['categories'], const ['cs.AI', 'cs.LG']),
      isEnabled: _parseBool(json['is_enabled']),
    );
  }
}
