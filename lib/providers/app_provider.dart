import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum ExtractionStatus { idle, loading, success, error }

class AppProvider extends ChangeNotifier {
  final ApiService api;
  final StorageService storage;

  List<ScheduleEvent> events = [];
  List<Todo> todos = [];
  ExtractionStatus status = ExtractionStatus.idle;
  String? errorMessage;
  String? pendingFilePath;

  AppProvider({required this.api, required this.storage});

  // ── Load & sync ────────────────────────────────────────────────────────────

  Future<void> loadLocal() async {
    events = await storage.getEvents();
    todos = await storage.getTodos();
    notifyListeners();
    // Sync from server in the background; update UI when done
    unawaited(_syncFromServer());
  }

  Future<void> _syncFromServer() async {
    try {
      final result = await api.getItems();
      await storage.replaceAll(result.events, result.todos);
      events = result.events;
      todos = result.todos;
      notifyListeners();
    } catch (_) {
      // Keep local cache on network error
    }
  }

  // ── Extraction ─────────────────────────────────────────────────────────────

  Future<bool> extractFromText(String text) =>
      _extract(() => api.extractFromText(text));

  Future<bool> extractFromImage(File file) =>
      _extract(() => api.extractFromImage(file));

  Future<bool> extractFromFile(File file, String type) =>
      _extract(() => api.extractFromFile(file, type));

  Future<bool> _extract(Future<ExtractionResult> Function() fn) async {
    status = ExtractionStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await fn();
      // Server already saved the new items; sync full list to stay consistent
      await _syncFromServer();
      status = ExtractionStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      status = ExtractionStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Event mutations (server-first) ─────────────────────────────────────────

  Future<void> updateEvent(ScheduleEvent event) async {
    final updated = await api.updateEventApi(event);
    await storage.updateEvent(updated);
    _replaceEvent(updated);
  }

  Future<void> deleteEvent(int id) async {
    await api.deleteEventApi(id);
    await storage.deleteEvent(id);
    events = events.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> toggleEventPin(int id, bool isPinned) async {
    await api.pinEventApi(id, isPinned);
    await storage.updateEventPinned(id, isPinned);
    _replaceEvent(events.firstWhere((e) => e.id == id).copyWith(isPinned: isPinned));
    _sortEvents();
  }

  // ── Todo mutations (server-first) ──────────────────────────────────────────

  Future<void> updateTodo(Todo todo) async {
    final updated = await api.updateTodoApi(todo);
    await storage.updateTodo(updated);
    _replaceTodo(updated);
  }

  Future<void> deleteTodo(int id) async {
    await api.deleteTodoApi(id);
    await storage.deleteTodo(id);
    todos = todos.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> toggleTodo(int id, bool isDone) async {
    await api.toggleTodoDoneApi(id, isDone);
    await storage.updateTodoDone(id, isDone);
    _replaceTodo(todos.firstWhere((t) => t.id == id).copyWith(isDone: isDone));
    _sortTodos();
  }

  Future<void> toggleTodoPin(int id, bool isPinned) async {
    await api.pinTodoApi(id, isPinned);
    await storage.updateTodoPinned(id, isPinned);
    _replaceTodo(todos.firstWhere((t) => t.id == id).copyWith(isPinned: isPinned));
    _sortTodos();
  }

  // ── Clear all ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await storage.clearAll();
    events = [];
    todos = [];
    notifyListeners();
  }

  // ── Pending file (iOS share) ───────────────────────────────────────────────

  void setPendingFile(String path) {
    pendingFilePath = path;
    notifyListeners();
  }

  void clearPendingFile() {
    pendingFilePath = null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _replaceEvent(ScheduleEvent updated) {
    final idx = events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      final list = List<ScheduleEvent>.from(events);
      list[idx] = updated;
      events = list;
      notifyListeners();
    }
  }

  void _replaceTodo(Todo updated) {
    final idx = todos.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      final list = List<Todo>.from(todos);
      list[idx] = updated;
      todos = list;
      notifyListeners();
    }
  }

  void _sortEvents() {
    events = List<ScheduleEvent>.from(events)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final dc = (a.date ?? '').compareTo(b.date ?? '');
        return dc != 0 ? dc : (a.time ?? '').compareTo(b.time ?? '');
      });
    notifyListeners();
  }

  void _sortTodos() {
    todos = List<Todo>.from(todos)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return (a.deadline ?? '').compareTo(b.deadline ?? '');
      });
    notifyListeners();
  }

  // ── AI Chat Planning ──────────────────────────────────────────────────────

  String? _currentSessionId;
  List<ChatMessage> _chatHistory = [];
  ChatDraft? _currentDraft;
  bool _chatLoading = false;

  String? get currentSessionId => _currentSessionId;
  List<ChatMessage> get chatHistory => _chatHistory;
  ChatDraft? get currentDraft => _currentDraft;
  bool get chatLoading => _chatLoading;

  Future<void> startChatPlanning(String request) async {
    _chatLoading = true;
    notifyListeners();
    try {
      final result = await api.startChatPlanning(request);
      _currentSessionId = result['session_id'] as String?;
      _chatHistory = [
        ChatMessage(role: ChatMessageRole.user, content: request),
        ChatMessage(
            role: ChatMessageRole.assistant,
            content: result['ai_response'] as String? ?? ''),
      ];
      _chatLoading = false;
      notifyListeners();
    } catch (e) {
      _chatLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendChatMessage(String message) async {
    if (_currentSessionId == null) {
      await startChatPlanning(message);
      return;
    }
    _chatHistory = [
      ..._chatHistory,
      ChatMessage(role: ChatMessageRole.user, content: message),
    ];
    _chatLoading = true;
    notifyListeners();
    try {
      final result = await api.sendChatMessage(
        sessionId: _currentSessionId!,
        message: message,
      );
      _chatHistory = [
        ..._chatHistory,
        ChatMessage(
            role: ChatMessageRole.assistant,
            content: result['ai_response'] as String? ?? ''),
      ];
      _chatLoading = false;
      notifyListeners();
    } catch (e) {
      _chatLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createDraft(String message) async {
    if (_currentSessionId == null) return;
    _chatLoading = true;
    notifyListeners();
    try {
      final result = await api.createDraft(
        sessionId: _currentSessionId!,
        message: message,
      );
      _currentDraft = ChatDraft.fromJson(
          _asMap(result['draft'] ?? result));
      _chatLoading = false;
      notifyListeners();
    } catch (e) {
      _chatLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmDraft(bool confirm) async {
    if (_currentDraft == null) return;
    await api.confirmDraft(
      draftId: _currentDraft!.id,
      confirm: confirm,
    );
    if (confirm) {
      await _syncFromServer();
    }
    _currentDraft = null;
    _currentSessionId = null;
    _chatHistory = [];
    notifyListeners();
  }

  void clearChat() {
    _currentSessionId = null;
    _chatHistory = [];
    _currentDraft = null;
    _chatLoading = false;
    notifyListeners();
  }

  void cancelChatRequest() {
    _chatLoading = false;
    if (_chatHistory.isNotEmpty &&
        _chatHistory.last.role == ChatMessageRole.user) {
      _chatHistory = _chatHistory.sublist(0, _chatHistory.length - 1);
    }
    notifyListeners();
  }

  // ── User Profile / Interests ─────────────────────────────────────────────

  List<Interest> _interests = [];
  Map<String, dynamic>? _profileSummary;
  bool _profileLoading = false;

  List<Interest> get interests => _interests;
  Map<String, dynamic>? get profileSummary => _profileSummary;
  bool get profileLoading => _profileLoading;

  Future<void> loadInterests() async {
    _profileLoading = true;
    notifyListeners();
    try {
      _interests = await api.getInterests();
      _profileLoading = false;
      notifyListeners();
    } catch (e) {
      _profileLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addInterest({
    required String category,
    required String tag,
    required List<String> keywords,
    double weight = 1.0,
  }) async {
    await api.addInterest(
      category: category,
      tag: tag,
      keywords: keywords,
      weight: weight,
    );
    await loadInterests();
  }

  Future<void> deleteInterest(int interestId) async {
    await api.deleteInterest(interestId);
    await loadInterests();
  }

  Future<void> loadProfileSummary() async {
    _profileSummary = await api.getProfileSummary();
    notifyListeners();
  }

  // ── Recommendations ──────────────────────────────────────────────────────

  List<RecommendationItem> _recommendations = [];
  int _recommendationTotal = 0;
  bool _recommendationsLoading = false;

  List<RecommendationItem> get recommendations => _recommendations;
  int get recommendationTotal => _recommendationTotal;
  bool get recommendationsLoading => _recommendationsLoading;

  Future<void> loadRecommendations({bool unreadOnly = false}) async {
    _recommendationsLoading = true;
    notifyListeners();
    try {
      final result = await api.getRecommendations(unreadOnly: unreadOnly);
      final items = result['items'] as List<dynamic>? ?? [];
      _recommendations = items
          .map((e) => RecommendationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _recommendationTotal = result['total'] as int? ?? 0;
      _recommendationsLoading = false;
      notifyListeners();
    } catch (e) {
      _recommendationsLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markRecommendationRead(int contentId) async {
    await api.markAsRead(contentId);
    _recommendations = _recommendations.map((r) {
      if (r.contentId == contentId) {
        return RecommendationItem(
          id: r.id,
          contentId: r.contentId,
          score: r.score,
          read: true,
          saved: r.saved,
          source: r.source,
          title: r.title,
          description: r.description,
          url: r.url,
          author: r.author,
          publishedDate: r.publishedDate,
          contentType: r.contentType,
          tags: r.tags,
        );
      }
      return r;
    }).toList();
    notifyListeners();
  }

  Future<void> saveRecommendation(int contentId) async {
    await api.saveContent(contentId);
    _recommendations = _recommendations.map((r) {
      if (r.contentId == contentId) {
        return RecommendationItem(
          id: r.id,
          contentId: r.contentId,
          score: r.score,
          read: r.read,
          saved: true,
          source: r.source,
          title: r.title,
          description: r.description,
          url: r.url,
          author: r.author,
          publishedDate: r.publishedDate,
          contentType: r.contentType,
          tags: r.tags,
        );
      }
      return r;
    }).toList();
    notifyListeners();
  }

  // ── arXiv Daily Report ───────────────────────────────────────────────────

  ArxivReport? _todayReport;
  List<ArxivReport> _reportHistory = [];
  ArxivPreference _arxivPreference = const ArxivPreference();
  bool _reportLoading = false;

  ArxivReport? get todayReport => _todayReport;
  List<ArxivReport> get reportHistory => _reportHistory;
  ArxivPreference get arxivPreference => _arxivPreference;
  bool get reportLoading => _reportLoading;

  Future<void> loadTodayReport() async {
    _reportLoading = true;
    notifyListeners();
    try {
      _todayReport = await api.getTodayReport();
      _reportLoading = false;
      notifyListeners();
    } catch (e) {
      _todayReport = null;
      _reportLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReportHistory() async {
    _reportLoading = true;
    notifyListeners();
    try {
      _reportHistory = await api.getReports();
      _reportLoading = false;
      notifyListeners();
    } catch (e) {
      _reportLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> generateReport({String? reportDate}) async {
    _reportLoading = true;
    notifyListeners();
    try {
      final report = await api.generateReport(reportDate: reportDate);
      _todayReport = report;
      _reportLoading = false;
      notifyListeners();
    } catch (e) {
      _reportLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadArxivPreference() async {
    try {
      _arxivPreference = await api.getArxivPreference();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateArxivPreference({
    String? pushTime,
    int? paperCount,
    List<String>? categories,
    bool? isEnabled,
  }) async {
    _arxivPreference = await api.updateArxivPreference(
      pushTime: pushTime,
      paperCount: paperCount,
      categories: categories,
      isEnabled: isEnabled,
    );
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _asMap(dynamic d) =>
      d is String ? jsonDecode(d) as Map<String, dynamic> : d as Map<String, dynamic>;
}
