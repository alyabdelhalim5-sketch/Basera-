# Basera (بصيرة) — On-Device AI Smart Glasses for the Visually Impaired

Basera is an edge-AI vision assistant pipeline designed for smart glasses. It captures real-time scenes, detects visual changes, analyzes the view using lightweight Vision-Language Models (SmolVLM2-500M), and generates concise, direct spoken descriptions for visually impaired users — entirely offline.

---

## 🌟 Key Features

- **Local & Offline Inference**: Runs 100% on-device without cloud dependency.
- **Event-Driven Change Detection**: Skips heavy neural inference when the scene is static (<5ms check), saving battery and preventing device overheating.
- **Direct Camera Capture**: Captures frames from webcams or USB smart glasses cameras and automatically archives them with timestamps in `captured_images/`.
- **Concise Navigation Descriptions**: Tuned prompts prioritize immediate physical obstacles, stairs, doorways, people, and hazards in one short sentence.
- **Offline Speech Synthesis**: Generates audio descriptions directly on Windows via native SAPI / System.Speech.

---

## 📁 Repository Structure

```text
├── pipeline.py                 # Core end-to-end smart glasses pipeline (Camera -> VLM -> TTS)
├── test_pipeline_flow.py       # Simulates real-time streaming & change detection
├── test_optimizations.py       # Latency & resolution benchmarking suite
├── tts.ps1                     # Offline Windows speech synthesizer script
├── requirements.txt            # Python dependencies
├── test_images/                # Sample scenes (street, indoor, stairs, etc.)
└── README.md                   # Project documentation
```

---

## 🚀 Quick Start

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

### 2. Run from Camera (Smart Glasses or Webcam)
Capture directly from connected camera (default index 0) and analyze:

```powershell
python pipeline.py --camera 0 --no-tts
```

Captured images are automatically saved to `captured_images/capture_YYYYMMDD_HHMMSS.jpg` and `captured_images/latest_capture.jpg`.

### 3. Run on an Existing Image

```powershell
python pipeline.py --image test_images\street.jpg --resolution 256 --tokens 15 --no-tts
```

### 4. Run Stream Simulation (Change Detection Test)

```powershell
python test_pipeline_flow.py
```

---

## 📊 Measured On-Device Benchmarks

Tested on Intel Core i7 (9th Gen, 6C/12T) with Intel UHD Graphics 630:

| Mode | Resolution | Tokens | Latency | Behavior |
|---|---|---|---|---|
| **Static / Unchanged Scene** | 256×256 | 0 | **5.2 ms** | **Bypassed (99.9% power saved)** |
| **Active Scene (SmolVLM2)** | 256×256 | 15 | **~24-27 s** | Full visual scene understanding |
| **Target Mobile (LiteRT-LM NPU)** | 256×256 | 15 | **~1.2-1.5 s** | Pre-compiled INT4 on phone NPU |

---

## 📄 License
Apache 2.0
