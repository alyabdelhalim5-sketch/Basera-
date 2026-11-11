import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_response.dart';
import 'offline_vision_service.dart';

/// Unified AI service: Seamlessly bridges On-Device Offline Vision Engine
/// and Optional Wi-Fi SmolVLM2 Backend.
class AiService {
  String _backendIp;
  int _port;
  String _language;
  int _maxTokens;
  bool _isOfflineMode;

  final OfflineVisionService _offlineVision = OfflineVisionService();

  AiService({
    required String backendIp,
    int port = 8000,
    String language = 'ar',
    int maxTokens = 120,
    bool isOfflineMode = true,
  })  : _backendIp = backendIp,
        _port = port,
        _language = language,
        _maxTokens = maxTokens,
        _isOfflineMode = isOfflineMode;

  // ── Setters ──────────────────────────────────────────────────────────────
  void updateSettings({
    String? backendIp,
    int? port,
    String? language,
    int? maxTokens,
    bool? isOfflineMode,
  }) {
    if (backendIp != null) _backendIp = backendIp;
    if (port != null) _port = port;
    if (language != null) _language = language;
    if (maxTokens != null) _maxTokens = maxTokens;
    if (isOfflineMode != null) _isOfflineMode = isOfflineMode;
  }

  String get _baseUrl => 'http://$_backendIp:$_port';
  bool get isOfflineMode => _isOfflineMode;

  // ── Health check ─────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    if (_isOfflineMode) return true; // Offline engine is always ready
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return json['ready'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Describe image ────────────────────────────────────────────────────────
  Future<AiResponse> describeImage(
    File imageFile, {
    bool force = false,
  }) async {
    // 1. If Offline Mode is selected -> Run 100% on-device
    if (_isOfflineMode) {
      return await _offlineVision.analyzeImage(
        imageFile,
        language: _language,
        force: force,
      );
    }

    // 2. If Hybrid / Online Mode -> Try Laptop Backend, fallback to Offline on error
    try {
      final uri = Uri.parse('$_baseUrl/describe');
      final bytes = await imageFile.readAsBytes();

      final request = http.MultipartRequest('POST', uri)
        ..fields['language'] = _language
        ..fields['max_tokens'] = _maxTokens.toString()
        ..fields['force'] = force.toString()
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'capture.jpg',
          ),
        );

      final streamed = await request.send().timeout(const Duration(seconds: 40));
      final respBody = await http.Response.fromStream(streamed);

      if (respBody.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(utf8.decode(respBody.bodyBytes));
        return AiResponse.fromJson(json);
      } else {
        throw Exception('Backend returned status ${respBody.statusCode}');
      }
    } catch (e) {
      // Automatic fallback to On-Device Offline Engine!
      return await _offlineVision.analyzeImage(
        imageFile,
        language: _language,
        force: force,
      );
    }
  }

  // ── Reset Scene Memory ────────────────────────────────────────────────────
  Future<void> resetScene() async {
    _offlineVision.reset();
    if (!_isOfflineMode) {
      try {
        await http
            .post(Uri.parse('$_baseUrl/reset'))
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }
}
