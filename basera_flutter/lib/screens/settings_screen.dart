import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _tokensController;
  String _language = 'ar';
  bool _testing = false;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _ipController = TextEditingController(text: settings.backendIp);
    _portController = TextEditingController(text: settings.backendPort.toString());
    _tokensController = TextEditingController(text: settings.maxTokens.toString());
    _language = settings.language;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tokensController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsService>();
    final ai = context.read<AiService>();
    final tts = context.read<TtsService>();
    final speech = context.read<SpeechService>();

    await settings.saveBackendIp(_ipController.text.trim());
    await settings.saveBackendPort(int.tryParse(_portController.text) ?? 8000);
    await settings.saveLanguage(_language);
    await settings.saveMaxTokens(int.tryParse(_tokensController.text) ?? 120);

    ai.updateSettings(
      backendIp: settings.backendIp,
      port: settings.backendPort,
      language: settings.language,
      maxTokens: settings.maxTokens,
    );
    tts.updateLanguage(settings.language);
    speech.updateLanguage(settings.language);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = '';
    });
    final ai = context.read<AiService>();
    // Temporarily update IP/port for testing
    ai.updateSettings(
      backendIp: _ipController.text.trim(),
      port: int.tryParse(_portController.text) ?? 8000,
    );
    final ok = await ai.checkHealth();
    setState(() {
      _testing = false;
      _testResult = ok ? '✅ Connected!' : '❌ Cannot reach server';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('⚙️ Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Backend Connection ───────────────────────────────────────────
          _sectionTitle('Backend Connection'),
          _textField(
            controller: _ipController,
            label: 'Server IP Address',
            hint: '192.168.1.100',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _portController,
            label: 'Port',
            hint: '8000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_testResult.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _testResult,
                style: TextStyle(
                  color: _testResult.startsWith('✅') ? Colors.green : Colors.red,
                ),
              ),
            ),

          const SizedBox(height: 28),

          // ── Language ─────────────────────────────────────────────────────
          _sectionTitle('Language / اللغة'),
          Row(
            children: [
              _langChoice('ar', 'العربية 🇸🇦'),
              const SizedBox(width: 12),
              _langChoice('en', 'English 🇬🇧'),
            ],
          ),

          const SizedBox(height: 28),

          // ── AI Settings ───────────────────────────────────────────────────
          _sectionTitle('AI Settings'),
          _textField(
            controller: _tokensController,
            label: 'Max description tokens (longer = slower)',
            hint: '120',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'Higher = richer descriptions but adds ~2s per 30 tokens on CPU.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),

          const SizedBox(height: 40),

          // ── Save ──────────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 28),
          // ── Info ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ℹ️  Run the Python server on your laptop:\n\n'
              'D:\\smart-glasses\\venv\\Scripts\\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000\n\n'
              'Make sure the phone and laptop are on the same Wi-Fi network.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
      );

  Widget _langChoice(String code, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _language = code),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _language == code ? Colors.blue.shade800 : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _language == code ? Colors.blue : Colors.grey.shade700,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      );
}
