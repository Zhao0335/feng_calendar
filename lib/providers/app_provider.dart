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

  // File path to import from iOS share / open-in
  String? pendingFilePath;

  AppProvider({required this.api, required this.storage});

  Future<void> loadLocal() async {
    events = await storage.getEvents();
    todos = await storage.getTodos();
    notifyListeners();
  }

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
      final result = await fn();
      await storage.insertEvents(result.events);
      await storage.insertTodos(result.todos);
      await loadLocal();
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

  Future<void> updateEvent(ScheduleEvent event) async {
    await storage.updateEvent(event);
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      final updated = List<ScheduleEvent>.from(events);
      updated[idx] = event;
      // Re-sort: pinned first, then by date/time
      updated.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final dateCompare = (a.date ?? '').compareTo(b.date ?? '');
        if (dateCompare != 0) return dateCompare;
        return (a.time ?? '').compareTo(b.time ?? '');
      });
      events = updated;
      notifyListeners();
    }
  }

  Future<void> updateTodo(Todo todo) async {
    await storage.updateTodo(todo);
    final idx = todos.indexWhere((t) => t.id == todo.id);
    if (idx != -1) {
      final updated = List<Todo>.from(todos);
      updated[idx] = todo;
      updated.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return (a.deadline ?? '').compareTo(b.deadline ?? '');
      });
      todos = updated;
      notifyListeners();
    }
  }

  Future<void> toggleEventPin(int id, bool isPinned) async {
    await storage.updateEventPinned(id, isPinned);
    final idx = events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final updated = List<ScheduleEvent>.from(events);
      updated[idx] = events[idx].copyWith(isPinned: isPinned);
      updated.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final dateCompare = (a.date ?? '').compareTo(b.date ?? '');
        if (dateCompare != 0) return dateCompare;
        return (a.time ?? '').compareTo(b.time ?? '');
      });
      events = updated;
      notifyListeners();
    }
  }

  Future<void> toggleTodoPin(int id, bool isPinned) async {
    await storage.updateTodoPinned(id, isPinned);
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = List<Todo>.from(todos);
      updated[idx] = todos[idx].copyWith(isPinned: isPinned);
      updated.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return (a.deadline ?? '').compareTo(b.deadline ?? '');
      });
      todos = updated;
      notifyListeners();
    }
  }

  Future<void> deleteEvent(int id) async {
    await storage.deleteEvent(id);
    events = events.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> deleteTodo(int id) async {
    await storage.deleteTodo(id);
    todos = todos.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> toggleTodo(int id, bool isDone) async {
    await storage.updateTodoDone(id, isDone);
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = List<Todo>.from(todos);
      updated[idx] = todos[idx].copyWith(isDone: isDone);
      todos = updated;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await storage.clearAll();
    events = [];
    todos = [];
    notifyListeners();
  }

  void setPendingFile(String path) {
    pendingFilePath = path;
    notifyListeners();
  }

  void clearPendingFile() {
    pendingFilePath = null;
  }
}
