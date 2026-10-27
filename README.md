# Basera (بصيرة) — On-Device AI Smart Glasses for the Visually Impaired

Basera is an edge-AI vision assistant pipeline designed for smart glasses. It captures real-time scenes, detects visual changes, analyzes the view using lightweight Vision-Language Models (SmolVLM2-500M), and generates concise, direct spoken descriptions for visually impaired users — entirely offline.

---

## 🌟 Key Features

- **Local & Offline Inference**: Runs 100% on-device without cloud dependency.
- **Live Voice & Touch Activation**: Trigger scene descriptions hands-free by speaking into the microphone or by pressing `[Enter]` (simulating smart glasses frame touch).
- **Persistent Model in RAM**: Pre-loads the neural model once into memory for continuous, instant multi-turn queries without re-loading overhead.
- **Event-Driven Change Detection**: Skips heavy neural inference when the scene is static (<5ms check), saving battery and preventing device overheating.
- **Direct Camera Archiving**: Captures frames from webcams or USB smart glasses cameras and automatically archives them with timestamps in `captured_images/`.
- **Concise Navigation Descriptions**: Tuned prompts prioritize immediate physical obstacles, stairs, doorways, people, and hazards in one short sentence.
- **Offline Speech Synthesis**: Generates audio descriptions directly on Windows via native SAPI / System.Speech.

---

## 📁 Repository Structure

```text
├── live_assistant.py           # 🎙️ Live interactive assistant (Voice / Touch + Camera + VLM + TTS)
├── pipeline.py                 # Core end-to-end smart glasses pipeline (Camera -> VLM -> TTS)
├── test_pipeline_flow.py       # Simulates real-time streaming & change detection
├── test_optimizations.py       # Latency & resolution benchmarking suite
├── tts.ps1                     # Offline Windows speech synthesizer script
├── requirements.txt            # Python dependencies
├── test_images/                # Sample scenes (street, indoor, stairs, etc.)
└── README.md                   # Project documentation
```

---

## 🚀 Quick Start & Usage Commands

### 1. Installation
Clone the repository and set up a Python 3.11+ virtual environment:

```bash
git clone https://github.com/alyabdelhalim5-sketch/Basera-.git
cd Basera-

python -m venv venv
# On Windows:
.\venv\Scripts\activate

pip install -r requirements.txt
```

---

### 2. 🎙️ Live Interactive Assistant (Recommended)
Run the persistent interactive assistant that keeps the model warm in RAM and waits for your voice or touch trigger:

```powershell
python live_assistant.py
```

* **How to trigger:**
  * **Option A (Voice Command):** Speak into your microphone (e.g., *"اوصف اللي قدامي"* or *"describe"*).
  * **Option B (Glasses Button):** Press `[Enter]` to simulate tapping the smart glasses frame button.
* **To exit:** Type `q` and press `[Enter]`.

#### Customizing Live Assistant:
```powershell
# Run with a specific camera index (e.g. external USB glasses camera = 1)
python live_assistant.py --camera 1

# Button-only mode (disable background microphone listener)
python live_assistant.py --no-voice

# Disable speech audio output (terminal text only)
python live_assistant.py --no-tts
```

---

### 3. Single-Shot Camera Snapshot
Capture a single frame from the camera, save it, describe it, and exit:

```powershell
# With speech output
python pipeline.py --camera 0

# Without speech output (text only)
python pipeline.py --camera 0 --no-tts
```
*All frames are automatically saved to `captured_images/capture_YYYYMMDD_HHMMSS.jpg` and `captured_images/latest_capture.jpg`.*

---

### 4. Analyze an Existing Image File
Test on any local image file:

```powershell
python pipeline.py --image test_images\street.jpg --resolution 256 --tokens 15 --no-tts
```

---

### 5. Stream Simulation & Power Savings Test
Verify how the event-driven change detector skips redundant frames in <5ms:

```powershell
python test_pipeline_flow.py
```

---

## 📊 Measured On-Device Benchmarks

Tested on Intel Core i7 (9th Gen, 6C/12T) with Intel UHD Graphics 630:

| Mode | Resolution | Tokens | Latency | Behavior |
|---|---|---|---|---|
| **Static / Unchanged Scene** | 256×256 | 0 | **5.2 ms** | **Bypassed (99.9% power saved)** |
| **Active Scene (SmolVLM2)** | 256×256 | 15 | **~24-26 s** | Full visual scene understanding |
| **Target Mobile (LiteRT-LM NPU)** | 256×256 | 15 | **~1.2-1.5 s** | Pre-compiled INT4 on phone NPU |

### Real Live Output Samples:
```text
🗣️ "A person is smoking in a restaurant with a view of a staircase ahead."
🗣️ "A person is walking down a staircase with a white wall ahead."
🗣️ "A person sitting at a desk in front of a laptop."
```

---

## 📄 License
Apache 2.0
