"""
SmolVLM2-500M Baseline Benchmark
=================================
Stage 1 — Measures end-to-end latency on your hardware.

Usage:
    python benchmark_smolvlm2.py
    python benchmark_smolvlm2.py --image path/to/image.jpg
    python benchmark_smolvlm2.py --image-dir test_images/
    python benchmark_smolvlm2.py --cpu      (force CPU even if CUDA available)
"""

import argparse
import json
import os
import sys
import time
import statistics
from pathlib import Path

import torch
from PIL import Image
from transformers import AutoModelForImageTextToText, AutoProcessor

# ── Config ──────────────────────────────────────────────────
MODEL_ID = "HuggingFaceTB/SmolVLM2-500M-Video-Instruct"
MAX_NEW_TOKENS = 40
NUM_WARMUP = 2
NUM_RUNS = 10
IMAGE_SIZES = [384, 512]

MESSAGES = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {
                "type": "text",
                "text": (
                    "You are a visual assistant for a visually impaired person. "
                    "Describe this scene in one or two short sentences. "
                    "Focus on people, obstacles, furniture, vehicles, stairs, "
                    "signs, and doors. Be concise and factual."
                ),
            },
        ],
    }
]


# ── Helpers ─────────────────────────────────────────────────
def get_device(force_cpu=False):
    if force_cpu or not torch.cuda.is_available():
        print("Device: CPU")
        return "cpu", torch.float32
    name = torch.cuda.get_device_name(0)
    vram = torch.cuda.get_device_properties(0).total_mem / 1e9
    print(f"Device: CUDA  |  GPU: {name}  |  VRAM: {vram:.1f} GB")
    return "cuda", torch.float16


def get_ram_mb():
    try:
        import psutil
        return psutil.Process().memory_info().rss / 1e6
    except ImportError:
        return 0.0


def load_image(path=None):
    if path and os.path.exists(path):
        return Image.open(path).convert("RGB"), os.path.basename(path)
    print("No local image — downloading sample scene...")
    import requests
    from io import BytesIO
    # Wikimedia Commons — freely licensed street scene
    url = (
        "https://upload.wikimedia.org/wikipedia/commons/thumb/"
        "a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg"
    )
    # Use a generic urban scene instead
    fallback_urls = [
        "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=640&q=80",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/24701-nature-natural-beauty.jpg/640px-24701-nature-natural-beauty.jpg",
    ]
    for u in fallback_urls:
        try:
            r = requests.get(u, timeout=15, headers={"User-Agent": "smart-glasses-benchmark/1.0"})
            r.raise_for_status()
            return Image.open(BytesIO(r.content)).convert("RGB"), "sample_scene"
        except Exception as e:
            print(f"  Download failed ({u[:60]}...): {e}")
    print("  Using synthetic placeholder image")
    return Image.new("RGB", (640, 480), (90, 120, 150)), "synthetic"


def run_one(processor, model, image, max_tokens):
    t0 = time.perf_counter()
    prompt = processor.apply_chat_template(MESSAGES, add_generation_prompt=True)
    inputs = processor(text=prompt, images=[image], return_tensors="pt")
    inputs = {k: v.to(model.device) if hasattr(v, "to") else v for k, v in inputs.items()}
    pre_ms = (time.perf_counter() - t0) * 1000

    t1 = time.perf_counter()
    with torch.no_grad():
        output_ids = model.generate(**inputs, max_new_tokens=max_tokens,
                                    do_sample=False, num_beams=1)
    if model.device.type == "cuda":
        torch.cuda.synchronize()
    inf_ms = (time.perf_counter() - t1) * 1000

    t2 = time.perf_counter()
    text = processor.decode(output_ids[0], skip_special_tokens=True)
    dec_ms = (time.perf_counter() - t2) * 1000

    # Extract assistant reply only
    for marker in ["Assistant:", "assistant\n", "ASSISTANT:"]:
        if marker.lower() in text.lower():
            text = text[text.lower().index(marker.lower()) + len(marker):].strip()
            break

    return {
        "preprocess_ms": pre_ms,
        "inference_ms": inf_ms,
        "decode_ms": dec_ms,
        "total_ms": pre_ms + inf_ms + dec_ms,
        "output_tokens": len(output_ids[0]),
        "text": text,
    }


# ── Main ─────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=str, default=None)
    parser.add_argument("--image-dir", type=str, default=None)
    parser.add_argument("--cpu", action="store_true")
    args = parser.parse_args()

    print("\n" + "=" * 62)
    print("  SmolVLM2-500M Benchmark  —  Stage 1")
    print("=" * 62)

    device, dtype = get_device(args.cpu)

    # ── Load images
    images, names = [], []
    if args.image_dir and os.path.isdir(args.image_dir):
        exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
        for f in sorted(Path(args.image_dir).glob("*")):
            if f.suffix.lower() in exts:
                images.append(Image.open(f).convert("RGB"))
                names.append(f.name)
        print(f"\nLoaded {len(images)} image(s) from '{args.image_dir}'")
    else:
        img, name = load_image(args.image)
        images.append(img)
        names.append(name)

    if not images:
        print("ERROR: no images found.")
        sys.exit(1)

    # ── Load model
    print(f"\nLoading model: {MODEL_ID}")
    print("(First run downloads ~1 GB of weights — please wait)")
    ram_before = get_ram_mb()
    t_load = time.perf_counter()

    processor = AutoProcessor.from_pretrained(MODEL_ID)
    model = AutoModelForImageTextToText.from_pretrained(
        MODEL_ID, torch_dtype=dtype, device_map=device
    )
    model.eval()

    load_s = time.perf_counter() - t_load
    ram_after = get_ram_mb()
    print(f"  Loaded in {load_s:.1f}s")

    if device == "cuda":
        alloc = torch.cuda.memory_allocated() / 1e6
        resv  = torch.cuda.memory_reserved() / 1e6
        print(f"  VRAM: {alloc:.0f} MB allocated | {resv:.0f} MB reserved")
    else:
        print(f"  RAM delta: +{ram_after - ram_before:.0f} MB")

    # ── Benchmark
    all_results = {}
    for img_size in IMAGE_SIZES:
        print(f"\n{'─' * 62}")
        print(f"  Resolution {img_size}×{img_size}  |  max_new_tokens={MAX_NEW_TOKENS}")
        print(f"{'─' * 62}")
        size_data = []

        for img, name in zip(images, names):
            resized = img.resize((img_size, img_size), Image.LANCZOS)

            # warmup
            for _ in range(NUM_WARMUP):
                run_one(processor, model, resized, MAX_NEW_TOKENS)

            runs = [run_one(processor, model, resized, MAX_NEW_TOKENS)
                    for _ in range(NUM_RUNS)]

            totals = [r["total_ms"] for r in runs]
            infs   = [r["inference_ms"] for r in runs]
            pres   = [r["preprocess_ms"] for r in runs]
            p95    = sorted(totals)[min(int(0.95 * len(totals)), len(totals) - 1)]
            tps    = runs[-1]["output_tokens"] / (runs[-1]["inference_ms"] / 1000)

            print(f"\n  📷 {name}")
            print(f"     total    median={statistics.median(totals):6.0f}ms  "
                  f"p95={p95:6.0f}ms  mean={statistics.mean(totals):6.0f}ms")
            print(f"     inference median={statistics.median(infs):6.0f}ms  "
                  f"preprocess={statistics.median(pres):5.0f}ms")
            print(f"     tokens={runs[-1]['output_tokens']}  "
                  f"speed={tps:.1f} tok/s")
            out = runs[-1]["text"][:160]
            print(f'     "{out}"')

            size_data.append({
                "image": name,
                "resolution": f"{img_size}x{img_size}",
                "median_total_ms":     round(statistics.median(totals)),
                "p95_total_ms":        round(p95),
                "mean_total_ms":       round(statistics.mean(totals)),
                "median_inference_ms": round(statistics.median(infs)),
                "median_preprocess_ms":round(statistics.median(pres)),
                "tokens_per_second":   round(tps, 1),
                "output_tokens":       runs[-1]["output_tokens"],
                "sample_output":       runs[-1]["text"][:300],
            })

        all_results[f"{img_size}x{img_size}"] = size_data

    # ── Save JSON report
    report = {
        "model": MODEL_ID,
        "device": device,
        "gpu": torch.cuda.get_device_name(0) if device == "cuda" else None,
        "vram_gb": round(torch.cuda.get_device_properties(0).total_mem / 1e9, 1)
                   if device == "cuda" else None,
        "dtype": str(dtype),
        "max_new_tokens": MAX_NEW_TOKENS,
        "num_warmup": NUM_WARMUP,
        "num_runs": NUM_RUNS,
        "cold_start_s": round(load_s, 1),
        "results": all_results,
    }
    out_path = "D:/smart-glasses/benchmark_results.json"
    with open(out_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'=' * 62}")
    print(f"  ✅ DONE — cold start: {load_s:.1f}s")
    print(f"  Results saved → {out_path}")
    print(f"{'=' * 62}\n")


if __name__ == "__main__":
    main()
