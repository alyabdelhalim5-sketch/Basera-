import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/glasses_service.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _glassesIpController;
  late TextEditingController _glassesPortController;

  bool _isOfflineMode = true;
  String _language = 'ar';
  bool _testingBackend = false;
  String _backendTestResult = '';
  bool _testingGlasses = false;
  String _glassesTestResult = '';

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _ipController = TextEditingController(text: settings.backendIp);
    _portController = TextEditingController(text: settings.backendPort.toString());
    _glassesIpController = TextEditingController(text: settings.glassesIp);
    _glassesPortController = TextEditingController(text: settings.glassesPort.toString());
    _isOfflineMode = settings.isOfflineMode;
    _language = settings.language;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _glassesIpController.dispose();
    _glassesPortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsService>();
    final ai = context.read<AiService>();
    final tts = context.read<TtsService>();
    final speech = context.read<SpeechService>();
    final glasses = context.read<GlassesService>();
    final provider = context.read<AppProvider>();

    await settings.saveIsOfflineMode(_isOfflineMode);
    await settings.saveLanguage(_language);
    await settings.saveBackendIp(_ipController.text.trim());
    await settings.saveBackendPort(int.tryParse(_portController.text) ?? 8000);
    await settings.saveGlassesIp(_glassesIpController.text.trim());
    await settings.saveGlassesPort(int.tryParse(_glassesPortController.text) ?? 80);

    ai.updateSettings(
      isOfflineMode: _isOfflineMode,
      language: _language,
      backendIp: settings.backendIp,
      port: settings.backendPort,
    );

    glasses.updateSettings(
      ip: settings.glassesIp,
      port: settings.glassesPort,
    );

    tts.updateLanguage(_language);
    speech.updateLanguage(_language);
    await provider.checkBackend();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'ar' ? 'تم حفظ الإعدادات بنجاح' : 'Settings saved'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testGlassesConnection() async {
    setState(() {
      _testingGlasses = true;
      _glassesTestResult = '';
    });

    final glasses = context.read<GlassesService>();
    glasses.updateSettings(
      ip: _glassesIpController.text.trim(),
      port: int.tryParse(_glassesPortController.text) ?? 80,
    );

    final ok = await glasses.checkConnection();
    setState(() {
      _testingGlasses = false;
      _glassesTestResult = ok
          ? (_language == 'ar' ? '✅ تم الاتصال بالنظارة بنجاح' : '✅ Connected to glasses')
          : (_language == 'ar' ? '❌ تعذر العثور على النظارة' : '❌ Could not reach glasses');
    });
  }

  Future<void> _testBackendConnection() async {
    setState(() {
      _testingBackend = true;
      _backendTestResult = '';
    });

    final ai = context.read<AiService>();
    ai.updateSettings(
      backendIp: _ipController.text.trim(),
      port: int.tryParse(_portController.text) ?? 8000,
      isOfflineMode: false,
    );

    final ok = await ai.checkHealth();
    setState(() {
      _testingBackend = false;
      _backendTestResult = ok
          ? (_language == 'ar' ? '✅ تم الاتصال بالخادم بنجاح' : '✅ Backend connected')
          : (_language == 'ar' ? '❌ تعذر الاتصال بالخادم' : '❌ Backend unreachable');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _language == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          title: Text(isAr ? 'الإعدادات' : 'Settings'),
          backgroundColor: const Color(0xFF0F172A),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              onPressed: _save,
              tooltip: isAr ? 'حفظ' : 'Save',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Offline AI Mode ──────────────────────────────────
            _buildSectionCard(
              title: isAr ? 'عقل الذكاء الاصطناعي (AI Engine)' : 'AI Engine',
              icon: Icons.psychology,
              children: [
                SwitchListTile(
                  title: Text(
                    isAr ? 'وضع الأوفلاين (بدون إنترنت تماماً)' : '100% Offline Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    isAr
                        ? 'يعمل محلياً على معالج الهاتف فورياً في 30ms دون اتصال باللابتوب أو الإنترنت'
                        : 'Processes locally on phone in <30ms with zero network',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  value: _isOfflineMode,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _isOfflineMode = val),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 2: Smart Glasses ────────────────────────────────────
            _buildSectionCard(
              title: isAr ? 'نظارة بصيرة الذكية (Basera Glasses)' : 'Basera Smart Glasses',
              icon: Icons.remove_red_eye,
              children: [
                TextField(
                  controller: _glassesIpController,
                  decoration: InputDecoration(
                    labelText: isAr ? 'عنوان IP للنظارة (Wi-Fi Direct)' : 'Glasses IP',
                    hintText: '192.168.4.1',
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _glassesPortController,
                  decoration: InputDecoration(
                    labelText: isAr ? 'منفذ البث (Port)' : 'Port',
                    hintText: '80',
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _testingGlasses ? null : _testGlassesConnection,
                  icon: _testingGlasses
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: Text(isAr ? 'اختبار اتصال النظارة' : 'Test Glasses Connection'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                ),
                if (_glassesTestResult.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_glassesTestResult, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 3: Language & Speech ────────────────────────────────
            _buildSectionCard(
              title: isAr ? 'اللغة والصوت' : 'Language & Speech',
              icon: Icons.language,
              children: [
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration: InputDecoration(
                    labelText: isAr ? 'لغة التطبيق والنطق' : 'Language',
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  dropdownColor: const Color(0xFF1E293B),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية (Arabic)')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _language = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 4: Optional Laptop Backend (Hybrid) ─────────────────
            if (!_isOfflineMode)
              _buildSectionCard(
                title: isAr ? 'خادم اللابتوب الاختياري (SmolVLM2 Backend)' : 'Laptop Backend',
                icon: Icons.laptop,
                children: [
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'عنوان IP للابتوب' : 'Laptop IP',
                      hintText: '10.0.0.109',
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'المنفذ (Port)' : 'Port',
                      hintText: '8000',
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testingBackend ? null : _testBackendConnection,
                    icon: _testingBackend
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link),
                    label: Text(isAr ? 'اختبار اتصال الخادم' : 'Test Backend Connection'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                  ),
                  if (_backendTestResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_backendTestResult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          ...children,
        ],
      ),
    );
  }
}
