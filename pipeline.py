"""
pipeline.py — Smart Glasses End-to-End Processing Pipeline
==========================================================
Captures/receives an image -> Preprocesses -> Evaluates Scene Change
-> Runs Optimized VLM -> Formats Concise Assistive Text -> Offline TTS.

Optimized for on-device CPU / Intel iGPU execution.
"""

import os
import sys
import time
import argparse
import subprocess
from pathlib import Path
from PIL import Image
import torch
from transformers import AutoProcessor, AutoModelForImageTextToText

LOCAL_MODEL_PATH = r"D:\smart-glasses\hf_cache\smolvlm2_model"
TTS_SCRIPT_PATH = r"D:\smart-glasses\tts.ps1"

ASSISTIVE_SYSTEM_PROMPT = (
    "Describe this scene in one short sentence. "
    "Focus on obstacles, people, vehicles, stairs, or hazards directly ahead."
)

CHAT_MESSAGES = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {"type": "text", "text": ASSISTIVE_SYSTEM_PROMPT},
        ],
    }
]

class SmartGlassesPipeline:
    def __init__(self, model_path=LOCAL_MODEL_PATH, target_resolution=256, max_new_tokens=18):
        self.model_path = model_path
        self.target_resolution = target_resolution
        self.max_new_tokens = max_new_tokens
        self.prev_image = None
        self.processor = None
        self.model = None

    def initialize(self):
        print(f"[Pipeline] Initializing models from {self.model_path} ...")
        t0 = time.perf_counter()
        self.processor = AutoProcessor.from_pretrained(self.model_path)
        self.model = AutoModelForImageTextToText.from_pretrained(
            self.model_path,
            dtype=torch.float32,
            device_map="cpu"
        )
        self.model.eval()
        load_time = time.perf_counter() - t0
        print(f"[Pipeline] Model ready in {load_time:.2f}s")
        return load_time

    def detect_change(self, current_img: Image.Image, threshold: float = 0.06) -> bool:
        """Fast perceptual difference to prevent redundant inference calls."""
        if self.prev_image is None:
            self.prev_image = current_img.copy()
            return True

        small_curr = current_img.resize((16, 16), Image.Resampling.BOX).convert("L")
        small_prev = self.prev_image.resize((16, 16), Image.Resampling.BOX).convert("L")
        curr_bytes = list(small_curr.getdata())
        prev_bytes = list(small_prev.getdata())

        diff = sum(abs(c - p) for c, p in zip(curr_bytes, prev_bytes)) / (len(curr_bytes) * 255.0)
        self.prev_image = current_img.copy()
        return diff > threshold

    def process_image(self, image_input, trigger_tts: bool = True):
        metrics = {}
        t_start = time.perf_counter()

        if isinstance(image_input, (str, Path)):
            raw_img = Image.open(image_input).convert("RGB")
            img_name = os.path.basename(image_input)
        else:
            raw_img = image_input.convert("RGB")
            img_name = "frame"

        # 1. Change detection
        t_cd = time.perf_counter()
        changed = self.detect_change(raw_img)
        metrics["change_detection_ms"] = (time.perf_counter() - t_cd) * 1000
        metrics["scene_changed"] = changed

        if not changed:
            print(f"[Pipeline] Scene unchanged. Skipping expensive VLM inference.")
            metrics["status"] = "skipped_redundant"
            metrics["total_latency_ms"] = (time.perf_counter() - t_start) * 1000
            return metrics

        # 2. Preprocessing & Resizing
        t_pre = time.perf_counter()
        resized_img = raw_img.resize((self.target_resolution, self.target_resolution), Image.Resampling.LANCZOS)
        prompt = self.processor.apply_chat_template(CHAT_MESSAGES, add_generation_prompt=True)
        inputs = self.processor(text=prompt, images=[resized_img], return_tensors="pt")
        inputs = {k: v.to("cpu") if hasattr(v, "to") else v for k, v in inputs.items()}
        metrics["preprocess_ms"] = (time.perf_counter() - t_pre) * 1000

        # 3. VLM Inference
        t_inf = time.perf_counter()
        with torch.no_grad():
            output_ids = self.model.generate(
                **inputs,
                max_new_tokens=self.max_new_tokens,
                do_sample=False,
                num_beams=1,
            )
        metrics["inference_ms"] = (time.perf_counter() - t_inf) * 1000

        # 4. Decoding and Clean-up (isolate newly generated tokens only)
        t_dec = time.perf_counter()
        input_len = inputs["input_ids"].shape[1]
        generated_tokens = output_ids[0][input_len:]
        clean_text = self.processor.decode(generated_tokens, skip_special_tokens=True).strip()
        metrics["decode_ms"] = (time.perf_counter() - t_dec) * 1000
        metrics["description"] = clean_text

        # 5. Offline TTS
        if trigger_tts and clean_text:
            t_tts = time.perf_counter()
            self._synthesize_speech(clean_text)
            metrics["tts_ms"] = (time.perf_counter() - t_tts) * 1000
        else:
            metrics["tts_ms"] = 0.0

        metrics["total_latency_ms"] = (time.perf_counter() - t_start) * 1000
        return metrics

    def _synthesize_speech(self, text: str):
        try:
            cmd = [
                "powershell",
                "-ExecutionPolicy", "Bypass",
                "-File", TTS_SCRIPT_PATH,
                "-Text", text,
                "-OutFile", r"D:\smart-glasses\scene.wav"
            ]
            subprocess.run(cmd, capture_output=True, timeout=10)
        except Exception as e:
            print(f"[Pipeline] TTS warning: {e}")

def capture_from_camera(camera_index: int = 0, save_folder: str = r"D:\smart-glasses\captured_images") -> str:
    """
    Captures an image directly from the camera / smart glasses,
    saves it to disk with timestamp, and returns the saved file path.
    """
    import cv2
    from datetime import datetime

    os.makedirs(save_folder, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"capture_{timestamp}.jpg"
    filepath = os.path.join(save_folder, filename)
    latest_path = os.path.join(save_folder, "latest_capture.jpg")

    print(f"[Camera] Opening camera {camera_index} ...")
    cap = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    if not cap.isOpened():
        cap = cv2.VideoCapture(camera_index)

    if not cap.isOpened():
        raise RuntimeError(f"Could not open camera {camera_index}. Please check device connection or permissions.")

    # Warmup frames so sensor exposure and white balance adjust
    for _ in range(5):
        ret, frame = cap.read()

    cap.release()

    if not ret or frame is None:
        raise RuntimeError("Failed to capture a valid frame from the camera.")

    cv2.imwrite(filepath, frame)
    cv2.imwrite(latest_path, frame)
    print(f"[Camera] ✅ Frame captured and saved to:\n  -> {filepath}\n  -> {latest_path}")
    return filepath


def main():
    parser = argparse.ArgumentParser(description="Smart Glasses Inference Pipeline")
    parser.add_argument("--image", type=str, default=None,
                        help="Path to an existing image file (if not using camera)")
    parser.add_argument("--camera", type=int, default=None,
                        help="Camera device index (e.g., 0 for default webcam / smart glasses)")
    parser.add_argument("--save-dir", type=str, default=r"D:\smart-glasses\captured_images",
                        help="Directory where camera captures will be saved")
    parser.add_argument("--resolution", type=int, default=256)
    parser.add_argument("--tokens", type=int, default=18)
    parser.add_argument("--no-tts", action="store_true")
    args = parser.parse_args()

    # Determine image source
    if args.camera is not None:
        image_path = capture_from_camera(camera_index=args.camera, save_folder=args.save_dir)
    elif args.image is not None:
        image_path = args.image
    else:
        # Default behavior: if no image passed, default to camera 0
        print("[Pipeline] No image specified — capturing from default camera (index 0)...")
        try:
            image_path = capture_from_camera(camera_index=0, save_folder=args.save_dir)
        except Exception as e:
            print(f"[Pipeline] Camera capture unavailable ({e}) — falling back to sample street.jpg")
            image_path = r"D:\smart-glasses\test_images\street.jpg"

    pipeline = SmartGlassesPipeline(
        target_resolution=args.resolution,
        max_new_tokens=args.tokens
    )
    pipeline.initialize()

    print(f"\nProcessing image: {image_path} (resolution={args.resolution}x{args.resolution}, max_tokens={args.tokens})")
    res = pipeline.process_image(image_path, trigger_tts=(not args.no_tts))

    print("\n" + "=" * 55)
    print("  Smart Glasses Pipeline Output")
    print("=" * 55)
    print(f"  Captured Image:{image_path}")
    print(f"  Description:  \"{res.get('description', '')}\"")
    print(f"  Preprocess:    {res.get('preprocess_ms', 0):.1f} ms")
    print(f"  Inference:     {res.get('inference_ms', 0):.1f} ms")
    print(f"  TTS Synth:     {res.get('tts_ms', 0):.1f} ms")
    print(f"  Total Latency: {res.get('total_latency_ms', 0):.1f} ms")
    print("=" * 55)

if __name__ == "__main__":
    main()
