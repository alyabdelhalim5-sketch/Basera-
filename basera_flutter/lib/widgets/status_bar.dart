import 'package:flutter/material.dart';

enum AppState { idle, capturing, processing, speaking, error, noConnection, offlineReady }

class StatusBar extends StatelessWidget {
  final AppState state;
  final String? message;
  final String language;
  final bool isOfflineMode;
  final String activeSource; // 'phone' | 'glasses'

  const StatusBar({
    super.key,
    required this.state,
    this.message,
    this.language = 'ar',
    this.isOfflineMode = true,
    this.activeSource = 'phone',
  });

  String get _label {
    if (message != null && message!.isNotEmpty) return message!;
    if (language == 'ar') {
      return switch (state) {
        AppState.idle => 'جاهز • اضغط للتصوير أو قل "صف"',
        AppState.offlineReady => 'جاهز (الذكاء الاصطناعي الأوفلاين نشط)',
        AppState.capturing => activeSource == 'glasses' ? 'جاري السحب من النظارة…' : 'جاري التصوير…',
        AppState.processing => isOfflineMode
            ? 'المعالج الداخلي يحلل المشهد…'
            : 'الذكاء الاصطناعي يحلل المشهد…',
        AppState.speaking => 'يقرأ الوصف صوتياً…',
        AppState.error => 'حدث خطأ',
        AppState.noConnection => 'لا يوجد اتصال بالخادم',
      };
    } else {
      return switch (state) {
        AppState.idle => 'Ready • Tap to capture or say "describe"',
        AppState.offlineReady => 'Ready (Offline AI Active)',
        AppState.capturing => activeSource == 'glasses' ? 'Capturing from glasses…' : 'Capturing…',
        AppState.processing => isOfflineMode
            ? 'On-device AI analyzing scene…'
            : 'AI analyzing scene…',
        AppState.speaking => 'Speaking description…',
        AppState.error => 'An error occurred',
        AppState.noConnection => 'Cannot reach backend server',
      };
    }
  }

  Color get _color {
    return switch (state) {
      AppState.idle => const Color(0xFF10B981),
      AppState.offlineReady => const Color(0xFF10B981),
      AppState.capturing => Colors.lightBlueAccent,
      AppState.processing => Colors.amber,
      AppState.speaking => const Color(0xFF10B981),
      AppState.error => Colors.redAccent,
      AppState.noConnection => Colors.red.shade300,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withAlpha(200),
      child: Row(
        children: [
          if (state == AppState.processing || state == AppState.capturing)
            const Padding(
              padding: EdgeInsets.only(left: 10, right: 4),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 8, right: 6),
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _color.withAlpha(150), blurRadius: 6),
                ],
              ),
            ),
          Expanded(
            child: Text(
              _label,
              style: TextStyle(
                color: _color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOfflineMode
                  ? Colors.blueGrey.withAlpha(80)
                  : Colors.green.withAlpha(60),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOfflineMode ? Colors.blueGrey : Colors.green,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeSource == 'glasses' ? Icons.remove_red_eye : Icons.camera_alt,
                  size: 11,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  isOfflineMode ? '⚡ Offline' : '🌐 Hybrid',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
