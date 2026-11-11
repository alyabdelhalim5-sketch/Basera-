import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/ai_service.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/glasses_service.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Keep screen on during use
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Load cameras
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('No cameras available: $e');
  }

  // Load saved settings
  final settings = SettingsService();
  await settings.init();

  runApp(BaseraApp(cameras: cameras, settings: settings));
}

class BaseraApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final SettingsService settings;

  const BaseraApp({super.key, required this.cameras, required this.settings});

  @override
  Widget build(BuildContext context) {
    final aiService = AiService(
      backendIp: settings.backendIp,
      port: settings.backendPort,
      language: settings.language,
      maxTokens: settings.maxTokens,
      isOfflineMode: settings.isOfflineMode,
    );

    final ttsService = TtsService(language: settings.language);
    final speechService = SpeechService(language: settings.language);
    final glassesService = GlassesService(
      ip: settings.glassesIp,
      port: settings.glassesPort,
    );

    return MultiProvider(
      providers: [
        Provider<SettingsService>.value(value: settings),
        Provider<AiService>.value(value: aiService),
        Provider<TtsService>.value(value: ttsService),
        Provider<SpeechService>.value(value: speechService),
        Provider<GlassesService>.value(value: glassesService),
        ChangeNotifierProvider<AppProvider>(
          create: (_) => AppProvider(
            aiService: aiService,
            ttsService: ttsService,
            speechService: speechService,
            settingsService: settings,
            glassesService: glassesService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'بصيرة | Basera AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF10B981),
            surface: const Color(0xFF090D16),
          ),
          scaffoldBackgroundColor: const Color(0xFF090D16),
          useMaterial3: true,
        ),
        home: HomeScreen(cameras: cameras),
      ),
    );
  }
}
