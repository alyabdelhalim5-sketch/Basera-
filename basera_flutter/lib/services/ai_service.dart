import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_response.dart';

/// Communicates with the FastAPI backend running on the laptop.
class AiService {
  String _backendIp;
  int _port;
  String _language;
  int _maxTokens;

  AiService({
    required String backendIp,
    int port = 8000,
    String language = 'ar',
    int maxTokens = 120,
  })  : _backendIp = backendIp,
        _port = port,
        _language = language,
        _maxTokens = maxTokens;

  // ── Setters ──────────────────────────────────────────────────────────────
  void updateSettings({
    String? backendIp,
    int? port,
    String? language,
    int? maxTokens,
  }) {
    if (backendIp != null) _backendIp = backendIp;
    if (port != null) _port = port;
    if (language != null) _language = language;
    if (maxTokens != null) _maxTokens = maxTokens;
  }

  String get _baseUrl => 'http://$_backendIp:$_port';

  // ── Health check ─────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
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

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final respBody = await http.Response.fromStream(streamed);

    if (respBody.statusCode != 200) {
      throw Exception('Backend error ${respBody.statusCode}: ${respBody.body}');
    }

    final json = jsonDecode(respBody.body) as Map<String, dynamic>;
    return AiResponse.fromJson(json);
  }

  // ── Reset scene memory ────────────────────────────────────────────────────
  Future<void> resetScene() async {
    await http
        .post(Uri.parse('$_baseUrl/reset'))
        .timeout(const Duration(seconds: 5));
  }
}
