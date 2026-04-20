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
}
