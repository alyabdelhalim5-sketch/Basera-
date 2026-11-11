# بصيرة | Basera AI — Flutter Mobile App

> نظام ذكاء اصطناعي لوصف المشاهد للمكفوفين — يعمل على الموبايل عبر Wi-Fi

---

## Architecture (Option B: Wi-Fi Bridge)

```
┌─────────────────────────────────┐         Wi-Fi
│   Phone (Android / iOS)         │ ◄────────────────► ┌─────────────────────────────┐
│                                  │   HTTP POST /describe│   Laptop (Windows)          │
│  Flutter App                     │   image bytes        │                             │
│  ┌──────────┐ ┌──────────────┐  │ ──────────────────► │   FastAPI Server            │
│  │ Camera   │ │  flutter_tts │  │                      │   (api_server.py)           │
│  │ Preview  │ │  speech_to_  │  │ ◄────────────────── │                             │
│  └──────────┘ │  text        │  │   JSON response      │   SmolVLM2-500M Model       │
│               └──────────────┘  │   {description,...}  │   (hf_cache/smolvlm2_model) │
└─────────────────────────────────┘                      └─────────────────────────────┘
```

---

## Quick Start

### Step 1: Start the Python Backend (Laptop)

Double-click `start_server.bat` **or** run manually:

```bat
cd D:\smart-glasses
venv\Scripts\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000
```

Wait for: `✅ Model loaded and warm — ready for requests.`

**Find your laptop IP:**
```
ipconfig | findstr IPv4
```
Example: `192.168.1.105`

---

### Step 2: Setup Flutter (First Time Only)

> Requires Flutter SDK installed: https://docs.flutter.dev/get-started/install/windows

```bat
D:\smart-glasses\setup_flutter_project.bat
```

---

### Step 3: Connect Phone and Run

1. Enable **USB Debugging** on your Android phone
2. Connect via USB cable
3. Run:

```bat
cd D:\smart-glasses\basera_flutter
flutter run
```

---

### Step 4: Configure the App

1. Open the app → tap **⚙️** (top right)
2. Enter your **laptop IP** (e.g. `192.168.1.105`)
3. Tap **Test Connection** → should show ✅
4. Choose **Arabic** or **English**
5. Tap **Save**

---

## Features

| Feature | Status |
|---------|--------|
| Camera capture | ✅ |
| AI scene description (via Wi-Fi) | ✅ |
| Text-to-Speech (device TTS) | ✅ |
| Voice trigger ("صف" / "describe") | ✅ |
| Arabic + English | ✅ |
| Connection status indicator | ✅ |
| Settings screen (IP, language, tokens) | ✅ |
| Scene change detection (skip unchanged) | ✅ |
| iOS support | ⚠️ Requires macOS + Xcode to build |

---

## API Endpoints (Backend)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Check if model is loaded |
| `/describe` | POST | Send image → get description |
| `/reset` | POST | Clear scene memory |
| `/status` | GET | Detailed backend info |

---

## Expected Latency

| Phase | Time |
|-------|------|
| Camera capture | < 1s |
| Upload over Wi-Fi | < 1s |
| AI inference (CPU, 120 tokens) | 25–35s |
| TTS playback | 5–10s |

> **Total: ~30-40 seconds per description** — this is normal for CPU inference.
> The scene-change detection skips re-processing if nothing changed.

---

## Known Limitations

1. **Slow inference**: SmolVLM2 on CPU takes ~30s. GPU would be 5-10x faster.
2. **Wi-Fi required**: Phone and laptop must be on same network.
3. **iOS untested**: Requires macOS + Xcode. Code is cross-platform.
4. **TTS Arabic voice**: Quality depends on the Arabic TTS voice installed on the device.
5. **No offline mode**: Model must run on the laptop server.

---

## Files

```
D:\smart-glasses\
├── api_server.py              ← FastAPI backend (NEW)
├── start_server.bat           ← One-click server start (NEW)
├── setup_flutter_project.bat  ← Flutter project setup (NEW)
├── pipeline.py                ← Original AI pipeline (UNCHANGED)
├── live_assistant.py          ← Original CLI assistant (UNCHANGED)
└── basera_flutter/            ← Flutter app (NEW)
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   │   ├── home_screen.dart
    │   │   └── settings_screen.dart
    │   ├── services/
    │   │   ├── ai_service.dart
    │   │   ├── tts_service.dart
    │   │   ├── speech_service.dart
    │   │   └── settings_service.dart
    │   ├── models/
    │   │   └── ai_response.dart
    │   └── widgets/
    │       └── status_bar.dart
    ├── android/
    │   └── app/src/main/
    │       ├── AndroidManifest.xml
    │       └── res/xml/network_security_config.xml
    └── pubspec.yaml
```
