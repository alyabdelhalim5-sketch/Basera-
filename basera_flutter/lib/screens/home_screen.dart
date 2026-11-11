import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
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
  int _cameraIndex = 0;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<AppProvider>();
    await provider.init();
    await _startCamera();
  }

  Future<void> _startCamera() async {
    if (widget.cameras.isEmpty) return;

    final camera = widget.cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _startCamera();
    HapticFeedback.lightImpact();
  }

  Future<void> _captureFromPhone(AppProvider provider) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    HapticFeedback.mediumImpact();

    try {
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);
      await provider.describeFile(file);
    } catch (e) {
      debugPrint('Phone capture error: $e');
    }
  }

  void _onMainAction(AppProvider provider) {
    if (provider.activeSource == 'glasses') {
      HapticFeedback.mediumImpact();
      provider.captureFromGlasses();
    } else {
      _captureFromPhone(provider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.language == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header / Controls ─────────────────────────────────────────
              _buildTopBar(provider, isAr),

              // ── Viewfinder (Phone Camera or Smart Glasses) ────────────────
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (provider.activeSource == 'phone')
                      _buildPhoneCameraPreview()
                    else
                      _buildGlassesPreview(provider, isAr),

                    // Status Bar at the top of the viewfinder
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: StatusBar(
                        state: provider.state,
                        message: provider.statusDetail,
                        language: provider.language,
                        isOfflineMode: provider.isOfflineMode,
                        activeSource: provider.activeSource,
                      ),
                    ),

                    // Floating Description Card at the bottom of the viewfinder
                    if (provider.description.isNotEmpty)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: _buildDescriptionCard(provider, isAr),
                      ),
                  ],
                ),
              ),

              // ── Action Buttons Bar ────────────────────────────────────────
              _buildBottomActions(provider, isAr),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppProvider provider, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App Logo
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 8),
              Text(
                isAr ? 'بصيرة' : 'Basera',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Source Switcher Pill: [ 📱 هاتف | 👓 نظارة ]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              children: [
                _buildSourcePillOption(
                  icon: Icons.smartphone,
                  label: isAr ? 'الهاتف' : 'Phone',
                  isSelected: provider.activeSource == 'phone',
                  onTap: () => provider.setSource('phone'),
                ),
                _buildSourcePillOption(
                  icon: Icons.remove_red_eye,
                  label: isAr ? 'النظارة' : 'Glasses',
                  isSelected: provider.activeSource == 'glasses',
                  onTap: () => provider.setSource('glasses'),
                ),
              ],
            ),
          ),

          // Settings Icon
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePillOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneCameraPreview() {
    if (!_cameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _onMainAction(context.read<AppProvider>()),
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildGlassesPreview(AppProvider provider, bool isAr) {
    return Container(
      color: const Color(0xFF0A0F1D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981), width: 2),
              ),
              child: const Icon(
                Icons.remove_red_eye_rounded,
                size: 50,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isAr ? 'نظارة بصيرة الذكية متصلة' : 'Basera Smart Glasses Active',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'يتم سحب الصور من كاميرا النظارة مباشرة'
                  : 'Frames streamed directly from glasses camera',
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Wi-Fi Direct: ${provider.settingsService.glassesIp}',
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(AppProvider provider, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withAlpha(235),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 0.8),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'الوصف الصوتي:' : 'Scene Description:',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => provider.repeatDescription(),
                    tooltip: isAr ? 'إعادة النطق' : 'Repeat',
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white60, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => provider.resetScene(),
                    tooltip: isAr ? 'تصفير' : 'Reset',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            provider.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AppProvider provider, bool isAr) {
    final isProcessing = provider.state == AppState.processing || provider.state == AppState.capturing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          // Switch camera lens (phone mode only)
          if (provider.activeSource == 'phone')
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 28),
              onPressed: _switchCamera,
              tooltip: isAr ? 'تبديل العدسة' : 'Flip Lens',
            )
          else
            const SizedBox(width: 48),

          // Main Big Capture Button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton(
                onPressed: isProcessing ? null : () => _onMainAction(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    else
                      Icon(
                        provider.activeSource == 'glasses' ? Icons.remove_red_eye : Icons.camera_alt,
                        size: 24,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      isProcessing
                          ? (isAr ? 'جاري التحليل…' : 'Analyzing…')
                          : (isAr ? 'صف المشهد الآن' : 'Describe Scene'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Voice Command Button
          IconButton(
            icon: Icon(
              provider.isListening ? Icons.mic : Icons.mic_none,
              color: provider.isListening ? Colors.redAccent : Colors.white70,
              size: 28,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.toggleVoiceListen(
                onTriggerCamera: () => _captureFromPhone(provider),
              );
            },
            tooltip: isAr ? 'أمر صوتي' : 'Voice Command',
          ),
        ],
      ),
    );
  }
}
