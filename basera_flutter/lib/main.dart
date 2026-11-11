import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/ai_service.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (can change in settings later)
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

  runApp(BbaseraApp(cameras: cameras, settings: settings));
}

class BbaseraApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final SettingsService settings;

  const BbaseraApp({super.key, required this.cameras, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Settings (already initialized)
        Provider<SettingsService>.value(value: settings),

        // AI backend service
        Provider<AiService>(
          create: (_) => AiService(
            backendIp: settings.backendIp,
            port: settings.backendPort,
            language: settings.language,
            maxTokens: settings.maxTokens,
          ),
        ),

        // TTS
        Provider<TtsService>(
          create: (_) => TtsService(language: settings.language),
          dispose: (_, svc) => svc.dispose(),
        ),

        // Speech recognition
        Provider<SpeechService>(
          create: (_) => SpeechService(language: settings.language),
        ),
      ],
      child: MaterialApp(
        title: 'بصيرة | Basera',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue.shade700,
            surface: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
        ),
        home: HomeScreen(cameras: cameras),
      ),
    );
  }
}
