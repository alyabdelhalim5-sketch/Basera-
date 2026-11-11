import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages connection and frame capture from Basera Smart Glasses.
/// Connects over local Wi-Fi Direct AP (e.g. ESP32-CAM / Raspberry Pi)
/// with ZERO internet required.
class GlassesService {
  String _ip;
  int _port;

  GlassesService({
    String ip = '192.168.4.1',
    int port = 80,
  })  : _ip = ip,
        _port = port;

  String get ip => _ip;
  int get port => _port;
  String get baseUrl => 'http://$_ip:$_port';
  String get streamUrl => '$baseUrl:81/stream'; // Common ESP32-CAM MJPEG port

  void updateSettings({String? ip, int? port}) {
    if (ip != null) _ip = ip;
    if (port != null) _port = port;
  }

  /// Check if the smart glasses are reachable on the local direct network.
  Future<bool> checkConnection() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      try {
        // Fallback probe to root or capture
        final resp2 = await http
            .get(Uri.parse('$baseUrl/'))
            .timeout(const Duration(seconds: 2));
        return resp2.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  /// Capture a still frame snapshot from the smart glasses camera.
  Future<File> captureFrame() async {
    // Common snapshot endpoints for ESP32-CAM / Raspberry Pi camera modules
    final endpoints = [
      '$baseUrl/capture',
      '$baseUrl/snapshot.jpg',
      '$baseUrl/jpg',
      '$baseUrl/frame',
    ];

    http.Response? response;
    for (final url in endpoints) {
      try {
        final r = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 4));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          response = r;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'تعذر التقاط صورة من النظارة. تأكد من اتصال الهاتف بشبكة النظارة (Wi-Fi: Basera-Glasses)',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/glasses_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
}
