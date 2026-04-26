import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _keySession = 'auth_session_id';
  static const _keyUsername = 'auth_username';

  String? _sessionId;
  String? _username;

  String? get sessionId => _sessionId;
  String? get username => _username;
  bool get isLoggedIn => _sessionId != null;

  /// Call once at app startup to restore a saved session.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString(_keySession);
    _username = prefs.getString(_keyUsername);
    notifyListeners();
  }

  Future<String?> login(String baseUrl, String username, String password) async {
    try {
      final dio = _buildDio();
      final res = await dio.post(
        '$baseUrl/auth/login',
        data: {'username': username, 'password': password},
      );
      final sessionId = res.data['session_id'] as String;
      await _persist(sessionId, username);
      notifyListeners();
      return null; // success
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return '用户名或密码错误';
      if (e.response?.statusCode == 409) return '用户名已存在';
      return '网络错误：${e.message}';
    } catch (e) {
      return '登录失败：$e';
    }
  }

  Future<String?> register(String baseUrl, String username, String password) async {
    try {
      final dio = _buildDio();
      await dio.post(
        '$baseUrl/auth/register',
        data: {'username': username, 'password': password},
      );
      // Auto login after register
      return await login(baseUrl, username, password);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return '用户名已存在';
      return '网络错误：${e.message}';
    } catch (e) {
      return '注册失败：$e';
    }
  }

  Future<void> logout(String baseUrl) async {
    if (_sessionId == null) return;
    try {
      final dio = _buildDio();
      await dio.post(
        '$baseUrl/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $_sessionId'}),
      );
    } catch (_) {}
    await _clear();
    notifyListeners();
  }

  Future<void> _persist(String sessionId, String username) async {
    _sessionId = sessionId;
    _username = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySession, sessionId);
    await prefs.setString(_keyUsername, username);
  }

  Future<void> _clear() async {
    _sessionId = null;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
    await prefs.remove(_keyUsername);
  }

  Dio _buildDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ));
}
