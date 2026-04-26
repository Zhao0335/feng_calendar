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
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
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
    await prefs.setString(
        _baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  /// ISO date string of today, e.g. "2026-04-26", passed to backend so the
  /// model can resolve relative expressions like "后天", "下周三".
  String get _todayDate =>
      DateTime.now().toIso8601String().substring(0, 10);

  Future<bool> healthCheck() async {
    try {
      final base = await _getBaseUrl();
      final res = await _dio.get('$base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ExtractionResult> extractFromText(String text) async {
    final base = await _getBaseUrl();
    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({'text': text, 'current_date': _todayDate}),
      options: _authOptions,
    );
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromImage(File imageFile) async {
    final base = await _getBaseUrl();
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({
        'image_base64': b64,
        'image_mime': mime,
        'current_date': _todayDate,
      }),
      options: _authOptions,
    );
    return _parseResult(res.data);
  }

  Future<ExtractionResult> extractFromFile(File file, String fileType) async {
    final base = await _getBaseUrl();
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    final res = await _dio.post(
      '$base/extract',
      data: jsonEncode({
        'file_base64': b64,
        'file_type': fileType,
        'current_date': _todayDate,
      }),
      options: _authOptions,
    );
    return _parseResult(res.data);
  }

  ExtractionResult _parseResult(dynamic data) {
    // Dio auto-decodes JSON when response Content-Type is application/json.
    // If the server omits the header, data arrives as a raw String — decode it.
    Map<String, dynamic> map;
    if (data is String) {
      map = jsonDecode(data) as Map<String, dynamic>;
    } else {
      map = data as Map<String, dynamic>;
    }
    debugPrint('[API] response keys: ${map.keys.toList()}');
    debugPrint('[API] events count: ${(map["events"] as List?)?.length ?? 0},'
        ' todos count: ${(map["todos"] as List?)?.length ?? 0}');
    return ExtractionResult.fromJson(map);
  }
}
