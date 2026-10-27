"""
run_pipeline.py — End-to-end smart glasses pipeline (Stage 5 preview)
=======================================================================
Camera image → SmolVLM2-500M → concise description → Windows TTS

On Windows: uses pyttsx3 for offline TTS.
Usage:
    python run_pipeline.py --image path/to/image.jpg
    python run_pipeline.py --image path/to/image.jpg --no-tts
"""

import argparse
import time
import sys
import os
import json
import torch
from PIL import Image
from transformers import AutoModelForImageTextToText, AutoProcessor

MODEL_ID = "HuggingFaceTB/SmolVLM2-500M-Video-Instruct"
MAX_NEW_TOKENS = 40

MESSAGES_TEMPLATE = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {
                "type": "text",
                "text": (
                    "You are a visual assistant for a visually impaired person wearing smart glasses. "
                    "Describe what you see in ONE short sentence. "
                    "Mention: people, obstacles, vehicles, stairs, doors, signs. "
                    "Be direct. Start with what matters most."
                ),
            },
        ],
    }
]

_model = None
_processor = None


def load_model():
    global _model, _processor
    if _model is not None:
        return
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype  = torch.float16 if device == "cuda" else torch.float32
    print(f"[pipeline] Loading model on {device.upper()}...")
    t0 = time.perf_counter()
    _processor = AutoProcessor.from_pretrained(MODEL_ID)
    _model = AutoModelForImageTextToText.from_pretrained(
        MODEL_ID, torch_dtype=dtype, device_map=device
    ).eval()
    print(f"[pipeline] Ready in {time.perf_counter() - t0:.1f}s")


def describe_image(image: Image.Image) -> tuple[str, float]:
    """
    Returns (description_text, inference_time_seconds).
    Model must be loaded first via load_model().
    """
    t0 = time.perf_counter()
    prompt = _processor.apply_chat_template(MESSAGES_TEMPLATE, add_generation_prompt=True)
    inputs = _processor(text=prompt, images=[image], return_tensors="pt")
    inputs = {k: v.to(_model.device) if hasattr(v, "to") else v for k, v in inputs.items()}

    with torch.no_grad():
        output_ids = _model.generate(
            **inputs,
            max_new_tokens=MAX_NEW_TOKENS,
            do_sample=False,
            num_beams=1,
        )
    if _model.device.type == "cuda":
        torch.cuda.synchronize()

    text = _processor.decode(output_ids[0], skip_special_tokens=True)
    # Strip prompt echo — keep only assistant reply
    for marker in ["assistant\n", "Assistant:", "ASSISTANT:"]:
        if marker.lower() in text.lower():
            idx = text.lower().index(marker.lower()) + len(marker)
            text = text[idx:].strip()
            break

    elapsed = time.perf_counter() - t0
    return text, elapsed


def speak(text: str):
    """Offline TTS using pyttsx3 (Windows SAPI / cross-platform)."""
    try:
        import pyttsx3
        engine = pyttsx3.init()
        engine.setProperty("rate", 160)   # words per minute
        engine.setProperty("volume", 1.0)
        engine.say(text)
        engine.runAndWait()
    except ImportError:
        print("[TTS] pyttsx3 not installed — printing only")
    except Exception as e:
        print(f"[TTS] Error: {e}")


def has_scene_changed(prev_image: Image.Image | None, curr_image: Image.Image,
                      threshold: float = 0.05) -> bool:
    """
    Lightweight pixel-level change detection.
    Returns True if the scene changed significantly.
    """
    if prev_image is None:
        return True
    import struct

    def hash_image(img):
        small = img.resize((16, 16), Image.LANCZOS).convert("L")
        return list(small.getdata())

    a = hash_image(prev_image)
    b = hash_image(curr_image)
    diff = sum(abs(x - y) for x, y in zip(a, b)) / (len(a) * 255)
    return diff > threshold


# ── CLI demo ────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True, help="Path to input image")
    parser.add_argument("--no-tts", action="store_true", help="Skip TTS output")
    parser.add_argument("--resize", type=int, default=384,
                        help="Resize longest edge to this (default: 384)")
    args = parser.parse_args()

    if not os.path.exists(args.image):
        print(f"ERROR: Image not found: {args.image}")
        sys.exit(1)

    load_model()

    img = Image.open(args.image).convert("RGB")
    img = img.resize((args.resize, args.resize), Image.LANCZOS)

    print(f"\n[pipeline] Analyzing image: {args.image} ({args.resize}×{args.resize})")
    t_total = time.perf_counter()

    description, inf_time = describe_image(img)
    total_time = time.perf_counter() - t_total

    print(f"\n{'─' * 50}")
    print(f"  Description: {description}")
    print(f"  Inference:   {inf_time*1000:.0f}ms")
    print(f"  Total:       {total_time*1000:.0f}ms")
    print(f"{'─' * 50}\n")

    if not args.no_tts:
        t_tts = time.perf_counter()
        speak(description)
        print(f"  TTS:         {(time.perf_counter()-t_tts)*1000:.0f}ms")


if __name__ == "__main__":
    main()
