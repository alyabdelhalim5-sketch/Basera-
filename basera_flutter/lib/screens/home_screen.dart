import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/settings_service.dart';
import '../models/ai_response.dart';
import '../widgets/status_bar.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  AppState _appState = AppState.idle;
  String _description = '';
  String _statusMessage = '';
  bool _backendConnected = false;
  bool _listeningForVoice = false;
  int _cameraIndex = 0;

  late AiService _aiService;
  late TtsService _ttsService;
  late SpeechService _speechService;
  late SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    _aiService = context.read<AiService>();
    _ttsService = context.read<TtsService>();
    _speechService = context.read<SpeechService>();
    _settingsService = context.read<SettingsService>();

    await _ttsService.init();
    await _speechService.init();
    await _startCamera();
    await _checkBackend();
  }

  Future<void> _startCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _statusMessage = 'No camera found on device';
        _appState = AppState.error;
      });
      return;
    }

    final camera = widget.cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,  // 720p — good quality / size balance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _statusMessage = 'Camera error: $e';
        _appState = AppState.error;
      });
    }
  }

  Future<void> _checkBackend() async {
    final ok = await _aiService.checkHealth();
    setState(() => _backendConnected = ok);
    if (!ok) {
      setState(() => _appState = AppState.noConnection);
    } else {
      setState(() => _appState = AppState.idle);
    }
  }

  Future<void> _captureAndDescribe({bool force = false}) async {
    if (_appState == AppState.processing || _appState == AppState.capturing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    // ── 1. Capture image ───────────────────────────────────────────────────
    setState(() {
      _appState = AppState.capturing;
      _statusMessage = '';
    });

    File imageFile;
    try {
      final xFile = await _cameraController!.takePicture();
      imageFile = File(xFile.path);
    } catch (e) {
      setState(() {
        _appState = AppState.error;
        _statusMessage = 'Camera capture failed: $e';
      });
      return;
    }

    // ── 2. Send to AI backend ──────────────────────────────────────────────
    setState(() => _appState = AppState.processing);

    try {
      final AiResponse resp = await _aiService.describeImage(imageFile, force: force);

      if (resp.skipped) {
        setState(() {
          _appState = AppState.idle;
          _statusMessage = _settingsService.language == 'ar'
              ? 'المشهد لم يتغير'
              : 'Scene unchanged – skipped';
        });
        return;
      }

      setState(() {
        _description = resp.description;
        _appState = AppState.speaking;
        _statusMessage = resp.latencySeconds;
      });

      // ── 3. Speak the description ─────────────────────────────────────────
      await _ttsService.speak(resp.description);
      setState(() => _appState = AppState.idle);
    } catch (e) {
      setState(() {
        _appState = AppState.error;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _toggleVoiceListen() async {
    if (_listeningForVoice) {
      await _speechService.stop();
      setState(() => _listeningForVoice = false);
      return;
    }

    setState(() => _listeningForVoice = true);
    await _speechService.listenOnce(
      onResult: (text) {
        setState(() => _listeningForVoice = false);
        if (_speechService.isTrigger(text)) {
          _captureAndDescribe();
        }
      },
      onStatus: (listening) {
        if (!listening) setState(() => _listeningForVoice = false);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  String get _lang => _settingsService.language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview ───────────────────────────────────────────────
          _buildCameraPreview(),

          // ── Description overlay ──────────────────────────────────────────
          if (_description.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _ttsService.speak(_description),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: _lang == 'ar' ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ),
            ),

          // ── Status bar (top) ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: StatusBar(
              state: _appState,
              message: _statusMessage.isNotEmpty ? _statusMessage : null,
              language: _lang,
            ),
          ),

          // ── Top-right: settings + connection indicator ───────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            right: 12,
            child: Column(
              children: [
                _iconBtn(
                  icon: Icons.settings,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiProvider(
                          providers: [
                            Provider.value(value: _settingsService),
                            Provider.value(value: _aiService),
                            Provider.value(value: _ttsService),
                            Provider.value(value: _speechService),
                          ],
                          child: const SettingsScreen(),
                        ),
                      ),
                    );
                    await _checkBackend();
                  },
                ),
                const SizedBox(height: 8),
                _iconBtn(
                  icon: _backendConnected ? Icons.wifi : Icons.wifi_off,
                  color: _backendConnected ? Colors.green : Colors.red,
                  onTap: _checkBackend,
                  tooltip: _backendConnected ? 'Connected' : 'Not connected',
                ),
                const SizedBox(height: 8),
                if (widget.cameras.length > 1)
                  _iconBtn(
                    icon: Icons.flip_camera_ios,
                    onTap: _flipCamera,
                  ),
              ],
            ),
          ),

          // ── Bottom action bar ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Force re-describe
                  _actionBtn(
                    icon: Icons.refresh,
                    label: _lang == 'ar' ? 'إعادة' : 'Rescan',
                    onTap: () => _captureAndDescribe(force: true),
                    color: Colors.blue.shade700,
                    size: 48,
                  ),
                  // Main capture button
                  GestureDetector(
                    onTap: () => _captureAndDescribe(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _appState == AppState.processing
                            ? Colors.orange
                            : Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        _appState == AppState.processing
                            ? Icons.hourglass_top
                            : Icons.camera_alt,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                  // Voice trigger
                  _actionBtn(
                    icon: _listeningForVoice ? Icons.mic : Icons.mic_none,
                    label: _lang == 'ar' ? 'صوت' : 'Voice',
                    onTap: _toggleVoiceListen,
                    color: _listeningForVoice ? Colors.red : Colors.grey.shade800,
                    size: 48,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: Text('Initializing camera…', style: TextStyle(color: Colors.white)),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Future<void> _flipCamera() async {
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _cameraController?.dispose();
    await _startCamera();
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    double size = 44,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, color: Colors.white, size: size * 0.5),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
}
