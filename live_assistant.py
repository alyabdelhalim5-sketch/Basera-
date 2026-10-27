"""
live_assistant.py — Interactive Live Camera & Voice Assistant for Smart Glasses
==============================================================================
Keeps SmolVLM2 warm in RAM.
Listens for user trigger:
  1. Press [Enter] (simulating Smart Glasses temple touch button).
  2. Voice trigger: speak into the microphone ("اوصف", "describe", or any speech).
Captures frame from camera -> Saves to disk -> Analyzes with VLM -> Speaks out result.
"""

import os
import sys
import time
import threading
import argparse
import numpy as np
import sounddevice as sd
from pipeline import SmartGlassesPipeline, capture_from_camera

BANNER = r"""
==================================================================
   👓 Basera Smart Glasses — Live Interactive Assistant 👓
==================================================================
  • Model is loaded and kept warm in RAM.
  • To capture & describe:
      [Option A] Press [Enter] (Glasses Button Touch)
      [Option B] Speak into the microphone (Voice Activation)
  • Type 'q' and press [Enter] to exit.
==================================================================
"""

class LiveAssistant:
    def __init__(self, camera_index=0, resolution=256, tokens=18, enable_tts=True):
        self.camera_index = camera_index
        self.resolution = resolution
        self.tokens = tokens
        self.enable_tts = enable_tts
        self.is_running = True
        self.is_processing = False
        self.pipeline = SmartGlassesPipeline(
            target_resolution=resolution,
            max_new_tokens=tokens
        )

    def startup(self):
        print("\n[System] Warming up AI models in RAM (one-time load)...")
        t0 = time.perf_counter()
        self.pipeline.initialize()
        print(f"[System] Ready in {time.perf_counter() - t0:.1f}s!\n")
        print(BANNER)

    def trigger_capture_and_describe(self, trigger_source="Manual"):
        if self.is_processing:
            print("[System] Already processing previous frame... please wait.")
            return

        self.is_processing = True
        print(f"\n📸 [TRIGGER: {trigger_source}] Taking live camera snapshot...")

        try:
            # 1. Capture and save frame
            saved_image_path = capture_from_camera(
                camera_index=self.camera_index,
                save_folder=r"D:\smart-glasses\captured_images"
            )

            # 2. Neural inference
            print("[System] Analyzing visual scene...")
            res = self.pipeline.process_image(saved_image_path, trigger_tts=self.enable_tts)

            description = res.get("description", "").strip()
            total_ms = res.get("total_latency_ms", 0)

            print("\n" + "─" * 55)
            print(f"  🗣️ الوصف البصري: \"{description}\"")
            print(f"  ⏱️ زمن التحليل:  {total_ms:.0f} ms")
            print("─" * 55)

        except Exception as e:
            print(f"[Error] Failed to process camera capture: {e}")

        finally:
            self.is_processing = False
            print("\n👉 جاهز! تحدث في المايكروفون أو اضغط [Enter] للقطة التالية (أو 'q' للخروج)...")

    def voice_listener_loop(self, energy_threshold=0.04):
        """Monitors microphone for voice activity in background."""
        sample_rate = 16000
        block_size = int(sample_rate * 0.25) # 250ms chunks

        def audio_callback(indata, frames, time_info, status):
            if not self.is_running or self.is_processing:
                return

            rms = np.sqrt(np.mean(indata**2))
            if rms > energy_threshold:
                # Voice detected
                threading.Thread(
                    target=self.trigger_capture_and_describe,
                    args=("Voice Trigger (Mic)",),
                    daemon=True
                ).start()

        try:
            with sd.InputStream(samplerate=sample_rate, channels=1,
                                blocksize=block_size, callback=audio_callback):
                while self.is_running:
                    time.sleep(0.1)
        except Exception as e:
            print(f"[Mic Warning] Background voice listener unavailable: {e}")

    def run(self, enable_voice=True):
        self.startup()

        # Start background voice listener thread
        if enable_voice:
            voice_thread = threading.Thread(target=self.voice_listener_loop, daemon=True)
            voice_thread.start()
            print("[Mic] Voice listener is ACTIVE. Speak into mic or press Enter.")
        else:
            print("[Button] Press Enter to capture.")

        # Foreground interactive loop
        while self.is_running:
            try:
                cmd = input().strip().lower()
                if cmd in ["q", "quit", "exit"]:
                    print("[System] Shutting down Live Assistant...")
                    self.is_running = False
                    break
                else:
                    self.trigger_capture_and_describe(trigger_source="Glasses Button (Enter)")
            except (KeyboardInterrupt, EOFError):
                self.is_running = False
                break


def main():
    parser = argparse.ArgumentParser(description="Basera Smart Glasses Live Assistant")
    parser.add_argument("--camera", type=int, default=0, help="Camera index (default 0)")
    parser.add_argument("--resolution", type=int, default=256, help="Image resolution (default 256)")
    parser.add_argument("--tokens", type=int, default=18, help="Max new tokens (default 18)")
    parser.add_argument("--no-tts", action="store_true", help="Disable speech synthesis")
    parser.add_argument("--no-voice", action="store_true", help="Disable mic voice trigger (Enter key only)")
    args = parser.parse_args()

    assistant = LiveAssistant(
        camera_index=args.camera,
        resolution=args.resolution,
        tokens=args.tokens,
        enable_tts=(not args.no_tts)
    )
    assistant.run(enable_voice=(not args.no_voice))


if __name__ == "__main__":
    main()
