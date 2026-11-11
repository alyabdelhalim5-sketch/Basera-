import 'package:flutter/material.dart';

enum AppState { idle, capturing, processing, speaking, error, noConnection }

class StatusBar extends StatelessWidget {
  final AppState state;
  final String? message;
  final String language;

  const StatusBar({
    super.key,
    required this.state,
    this.message,
    this.language = 'ar',
  });

  String get _label {
    if (message != null) return message!;
    if (language == 'ar') {
      return switch (state) {
        AppState.idle => 'اضغط للتصوير أو قل "صف"',
        AppState.capturing => 'جاري التصوير…',
        AppState.processing => 'الذكاء الاصطناعي يحلل المشهد…',
        AppState.speaking => 'يقرأ الوصف…',
        AppState.error => 'حدث خطأ',
        AppState.noConnection => 'لا يوجد اتصال بالخادم',
      };
    } else {
      return switch (state) {
        AppState.idle => 'Tap to capture or say "describe"',
        AppState.capturing => 'Capturing…',
        AppState.processing => 'AI is analyzing the scene…',
        AppState.speaking => 'Reading description…',
        AppState.error => 'An error occurred',
        AppState.noConnection => 'Cannot reach backend server',
      };
    }
  }

  Color get _color {
    return switch (state) {
      AppState.idle => Colors.white70,
      AppState.capturing => Colors.blue,
      AppState.processing => Colors.orange,
      AppState.speaking => Colors.green,
      AppState.error => Colors.red,
      AppState.noConnection => Colors.red.shade300,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withOpacity(0.65),
      child: Row(
        children: [
          if (state == AppState.processing || state == AppState.capturing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _color,
                ),
              ),
            ),
          Expanded(
            child: Text(
              _label,
              style: TextStyle(color: _color, fontSize: 14),
              textAlign: language == 'ar' ? TextAlign.right : TextAlign.left,
              textDirection:
                  language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}
