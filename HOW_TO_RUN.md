## Flutter App — Step-by-Step Run Guide

### Prerequisites Checklist
- [ ] Flutter SDK installed (run `install_flutter.bat` if not)
- [ ] Android Studio installed (for Android SDK)
- [ ] USB Debugging enabled on phone
- [ ] Phone connected via USB
- [ ] Python backend server running (`start_server.bat`)
- [ ] Phone and laptop on same Wi-Fi

### Step 1: Install Flutter (if not installed)
```
Double-click: D:\smart-glasses\install_flutter.bat
```
Then restart your terminal/CMD.

### Step 2: Verify Flutter
```
flutter doctor
```
You need at least: ✅ Flutter, ✅ Android toolchain

### Step 3: Initialize the Flutter project
```
Double-click: D:\smart-glasses\setup_flutter_project.bat
```

### Step 4: Start the AI backend server
```
Double-click: D:\smart-glasses\start_server.bat
```
Wait until you see: `✅ Model loaded and warm — ready for requests.`

### Step 5: Find your laptop's IP address
In the server window, look for the IPv4 address printed at startup.
Or run: `ipconfig | findstr IPv4`
Example: `192.168.1.105`

### Step 6: Connect your phone and run
```
cd D:\smart-glasses\basera_flutter
flutter devices        # list connected devices
flutter run            # run on connected device
```

### Step 7: Configure the app
1. Open app → tap ⚙️ (settings)
2. Enter laptop IP (e.g. `192.168.1.105`)
3. Tap **Test Connection** → ✅
4. Choose Arabic or English
5. Tap Save

### Step 8: Use the app
- **Tap the white circle** → captures photo + AI description
- **Say "صف" or "describe"** → voice trigger
- **Tap the description text** → replay TTS
- **Tap 🔄** → force new description even if scene unchanged

---

### Build Release APK (for sharing/sideloading)
```
Double-click: D:\smart-glasses\build_apk.bat
```
APK saved to: `basera_flutter\build\app\outputs\flutter-apk\app-release.apk`

---

### Troubleshooting

| Problem | Solution |
|---------|----------|
| "Cannot reach server" | Check IP, check server running, check same Wi-Fi |
| "Model not loaded" | Wait for server startup, check server terminal |
| Camera black screen | Grant camera permission in phone settings |
| No TTS voice | Install Arabic TTS voice in phone settings |
| Very slow (30s+) | Normal on CPU. Expected latency. |
| `flutter: command not found` | Run `install_flutter.bat` first |
