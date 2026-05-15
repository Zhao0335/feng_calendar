import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'auth_service.dart';

class ApiService {
  static const _baseUrlKey = 'server_base_url';
  static const _defaultBaseUrl = 'http://101.37.80.57:5522';

  final AuthService auth;
  late final Dio _dio;

  ApiService({required this.auth}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 180),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }

  Options get _authOptions {
    final sid = auth.sessionId;
    if (sid == null) return Options();
    return Options(headers: {'Authorization': 'Bearer $sid'});
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  // ── Health ─────────────────────────────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Extraction ─────────────────────────────────────────────────────────────

  Future<ExtractionResult> extractFromText(String text) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'text': text, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromImage(File imageFile) async {
    final base = await _getBaseUrl();
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'image_base64': b64, 'image_mime': mime, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromFile(File file, String fileType) async {
    final base = await _getBaseUrl();
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final res = await _dio.post('$base/extract',
        data: jsonEncode({'file_base64': b64, 'file_type': fileType, 'current_date': _todayDate}),
        options: _authOptions);
    return _parseResult(res.data);
  }

  ExtractionResult _parseResult(dynamic data) {
    final map = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    debugPrint('[API] events: ${(map["events"] as List?)?.length ?? 0},'
        ' todos: ${(map["todos"] as List?)?.length ?? 0}');
    return ExtractionResult.fromJson(map);
  }

  // ── Cloud sync: read all items ─────────────────────────────────────────────

  Future<ExtractionResult> getItems() async {
    final base = await _getBaseUrl();
    final res = await _dio.get('$base/items', options: _authOptions);
    return _parseResult(res.data);
  }

  // ── Events CRUD ────────────────────────────────────────────────────────────

  Future<ScheduleEvent> createEvent(ScheduleEvent event) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/items/events',
        data: jsonEncode(_eventBody(event)), options: _authOptions);
    return ScheduleEvent.fromJson(_asMap(res.data));
  }

  Future<ScheduleEvent> updateEventApi(ScheduleEvent event) async {
    final base = await _getBaseUrl();
    final res = await _dio.put('$base/items/events/${event.id}',
        data: jsonEncode(_eventBody(event)), options: _authOptions);
    return ScheduleEvent.fromJson(_asMap(res.data));
  }

  Future<void> deleteEventApi(int id) async {
    final base = await _getBaseUrl();
    await _dio.delete('$base/items/events/$id', options: _authOptions);
  }

  Future<void> pinEventApi(int id, bool isPinned) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/events/$id/pin',
        data: jsonEncode({'is_pinned': isPinned}), options: _authOptions);
  }

  // ── Todos CRUD ─────────────────────────────────────────────────────────────

  Future<Todo> createTodo(Todo todo) async {
    final base = await _getBaseUrl();
    final res = await _dio.post('$base/items/todos',
        data: jsonEncode(_todoBody(todo)), options: _authOptions);
    return Todo.fromJson(_asMap(res.data));
  }

  Future<Todo> updateTodoApi(Todo todo) async {
    final base = await _getBaseUrl();
    final res = await _dio.put('$base/items/todos/${todo.id}',
        data: jsonEncode(_todoBody(todo)), options: _authOptions);
    return Todo.fromJson(_asMap(res.data));
  }

  Future<void> deleteTodoApi(int id) async {
    final base = await _getBaseUrl();
    await _dio.delete('$base/items/todos/$id', options: _authOptions);
  }

  Future<void> toggleTodoDoneApi(int id, bool isDone) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/todos/$id/done',
        data: jsonEncode({'is_done': isDone}), options: _authOptions);
  }

  Future<void> pinTodoApi(int id, bool isPinned) async {
    final base = await _getBaseUrl();
    await _dio.patch('$base/items/todos/$id/pin',
        data: jsonEncode({'is_pinned': isPinned}), options: _authOptions);
  }

  // ── AI Chat Planning ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startChatPlanning(String userRequest) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/chat/start',
          data: jsonEncode({'user_request': userRequest}),
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String sessionId,
    required String message,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/chat/message',
          data: jsonEncode({
            'session_id': sessionId,
            'message': message,
          }),
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  Future<Map<String, dynamic>> createDraft({
    required String sessionId,
    required String message,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/chat/draft',
          data: jsonEncode({
            'session_id': sessionId,
            'message': message,
          }),
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  Future<Map<String, dynamic>> confirmDraft({
    required int draftId,
    required bool confirm,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/chat/confirm/$draftId',
          data: jsonEncode({
            'draft_id': draftId,
            'confirm': confirm,
          }),
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  Future<List<ChatMessage>> getChatHistory(String sessionId) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/chat/history/$sessionId',
          options: _authOptions);
      final list = res.data['messages'] as List<dynamic>? ?? [];
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  // ── User Profile / Interests ─────────────────────────────────────────────

  Future<List<Interest>> getInterests({String? category}) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/profile/interests',
          queryParameters: category != null ? {'category': category} : null,
          options: _authOptions);
      final list = res.data['interests'] as List<dynamic>? ?? [];
      return list
          .map((e) => Interest.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Interest> addInterest({
    required String category,
    required String tag,
    required List<String> keywords,
    double weight = 1.0,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/profile/interests',
          data: jsonEncode({
            'category': category,
            'tag': tag,
            'keywords': keywords,
            'weight': weight,
          }),
          options: _authOptions);
      return Interest.fromJson(_asMap(res.data['interest'] ?? res.data));
    });
  }

  Future<void> deleteInterest(int interestId) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      await _dio.delete('$base/profile/interests/$interestId',
          options: _authOptions);
    });
  }

  Future<Interest> updateInterest({
    required int interestId,
    List<String>? keywords,
    double? weight,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final data = <String, dynamic>{};
      if (keywords != null) data['keywords'] = keywords;
      if (weight != null) data['weight'] = weight;
      final res = await _dio.put('$base/profile/interests/$interestId',
          data: jsonEncode(data), options: _authOptions);
      return Interest.fromJson(_asMap(res.data['interest'] ?? res.data));
    });
  }

  Future<Map<String, dynamic>> getProfileSummary() async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res =
          await _dio.get('$base/profile/summary', options: _authOptions);
      return _asMap(res.data);
    });
  }

  // ── Recommendations ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRecommendations({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/recommendations/feed',
          queryParameters: {
            'unread_only': unreadOnly,
            'limit': limit,
            'offset': offset,
          },
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  Future<void> markAsRead(int contentId) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      await _dio.post('$base/recommendations/$contentId/read',
          options: _authOptions);
    });
  }

  Future<void> saveContent(int contentId) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      await _dio.post('$base/recommendations/$contentId/save',
          options: _authOptions);
    });
  }

  Future<Map<String, dynamic>> getRecommendationStats() async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/recommendations/stats/summary',
          options: _authOptions);
      return _asMap(res.data);
    });
  }

  // ── arXiv Daily Report ───────────────────────────────────────────────────

  Future<ArxivPreference> getArxivPreference() async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res =
          await _dio.get('$base/arxiv/preference', options: _authOptions);
      return ArxivPreference.fromJson(_asMap(res.data));
    });
  }

  Future<ArxivPreference> updateArxivPreference({
    String? pushTime,
    int? paperCount,
    List<String>? categories,
    bool? isEnabled,
  }) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final data = <String, dynamic>{};
      if (pushTime != null) data['push_time'] = pushTime;
      if (paperCount != null) data['paper_count'] = paperCount;
      if (categories != null) data['categories'] = categories;
      if (isEnabled != null) data['is_enabled'] = isEnabled;
      final res = await _dio.post('$base/arxiv/preference',
          data: jsonEncode(data), options: _authOptions);
      return ArxivPreference.fromJson(
          _asMap(res.data['preference'] ?? res.data));
    });
  }

  Future<ArxivReport> generateReport({String? reportDate}) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.post('$base/arxiv/report/generate',
          queryParameters:
              reportDate != null ? {'report_date': reportDate} : null,
          options: _authOptions);
      return ArxivReport.fromJson(_asMap(res.data['report'] ?? res.data));
    });
  }

  Future<ArxivReport?> getTodayReport() async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res =
          await _dio.get('$base/arxiv/report/today', options: _authOptions);
      final report = res.data['report'];
      if (report == null) return null;
      return ArxivReport.fromJson(_asMap(report));
    });
  }

  Future<List<ArxivReport>> getReports({int limit = 30}) async {
    return _safe(() async {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/arxiv/reports',
          queryParameters: {'limit': limit}, options: _authOptions);
      final list = res.data['reports'] as List<dynamic>? ?? [];
      return list
          .map((e) => ArxivReport.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _eventBody(ScheduleEvent e) => {
        'title': e.title,
        'date': e.date,
        'time': e.time,
        'location': e.location,
        'notes': e.notes,
        'is_pinned': e.isPinned,
      };

  Map<String, dynamic> _todoBody(Todo t) => {
        'title': t.title,
        'deadline': t.deadline,
        'priority': t.priority.name,
        'notes': t.notes,
        'is_done': t.isDone,
        'is_pinned': t.isPinned,
      };

  Map<String, dynamic> _asMap(dynamic d) =>
      d is String ? jsonDecode(d) as Map<String, dynamic> : d as Map<String, dynamic>;

  Future<T> _safe<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return Exception('连接超时，请检查网络');
        case DioExceptionType.sendTimeout:
          return Exception('发送超时');
        case DioExceptionType.receiveTimeout:
          return Exception('响应超时，AI推理可能需要较长时间');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 503) {
            return Exception('Ollama服务不可用，请确保服务已启动');
          } else if (statusCode == 504) {
            return Exception('AI推理超时，请稍后重试');
          } else if (statusCode == 401) {
            return Exception('未授权，请重新登录');
          }
          return Exception('服务器错误: $statusCode');
        case DioExceptionType.cancel:
          return Exception('请求已取消');
        case DioExceptionType.connectionError:
          return Exception('网络连接失败，请检查网络设置');
        default:
          return Exception('网络错误: ${error.message}');
      }
    }
    if (error is Exception) return error;
    return Exception('未知错误: $error');
  }
}
