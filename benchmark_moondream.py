"""
Moondream 0.5B Benchmark — Stage 2 (Comparison)
Run AFTER benchmark_smolvlm2.py to compare side-by-side.
"""

import json, os, time, statistics, sys
from pathlib import Path
import torch
from PIL import Image

MODEL_ID = "vikhyatk/moondream2"
REVISION  = "2025-01-09"   # pinned stable release with 0.5B weights
MAX_NEW_TOKENS = 40
NUM_WARMUP = 2
NUM_RUNS   = 10
IMAGE_SIZES = [384, 512]
CAPTION_PROMPT = "Describe this scene in one or two short sentences for a visually impaired person. Focus on people, obstacles, furniture, vehicles, stairs, signs, and doors."


def get_device():
    if torch.cuda.is_available():
        name = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_mem / 1e9
        print(f"CUDA: {name}  ({vram:.1f} GB VRAM)")
        return "cuda", torch.float16
    print("CPU mode")
    return "cpu", torch.float32


def main():
    print("\n" + "=" * 62)
    print("  Moondream 0.5B Benchmark  —  Stage 2")
    print("=" * 62)

    device, dtype = get_device()

    # Load a test image
    try:
        import requests
        from io import BytesIO
        r = requests.get("https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=640&q=80",
                         timeout=15, headers={"User-Agent": "smart-glasses/1.0"})
        img_orig = Image.open(BytesIO(r.content)).convert("RGB")
        img_name = "sample_scene"
    except Exception:
        img_orig = Image.new("RGB", (640, 480), (90, 120, 150))
        img_name = "synthetic"

    # Load model
    print(f"\nLoading: {MODEL_ID} (revision {REVISION})")
    print("(Downloads ~1 GB on first run)")
    t_load = time.perf_counter()

    from transformers import AutoModelForCausalLM
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID, revision=REVISION,
        trust_remote_code=True, torch_dtype=dtype,
    ).to(device).eval()
    tokenizer_obj = model.tokenizer  # Moondream bundles its own tokenizer

    load_s = time.perf_counter() - t_load
    print(f"  Loaded in {load_s:.1f}s")

    all_results = {}
    for img_size in IMAGE_SIZES:
        print(f"\n{'─' * 62}")
        print(f"  {img_size}×{img_size}  |  max_new_tokens={MAX_NEW_TOKENS}")
        print(f"{'─' * 62}")
        size_data = []
        img = img_orig.resize((img_size, img_size), Image.LANCZOS)

        # warmup
        for _ in range(NUM_WARMUP):
            enc = model.encode_image(img)
            model.answer_question(enc, CAPTION_PROMPT, tokenizer_obj,
                                  max_new_tokens=MAX_NEW_TOKENS)

        runs = []
        for _ in range(NUM_RUNS):
            t0 = time.perf_counter()
            enc = model.encode_image(img)
            enc_ms = (time.perf_counter() - t0) * 1000

            t1 = time.perf_counter()
            ans = model.answer_question(enc, CAPTION_PROMPT, tokenizer_obj,
                                        max_new_tokens=MAX_NEW_TOKENS)
            if device == "cuda":
                torch.cuda.synchronize()
            inf_ms = (time.perf_counter() - t1) * 1000

            runs.append({"enc_ms": enc_ms, "inf_ms": inf_ms,
                          "total_ms": enc_ms + inf_ms, "text": ans})

        totals = [r["total_ms"] for r in runs]
        encs   = [r["enc_ms"]   for r in runs]
        infs   = [r["inf_ms"]   for r in runs]
        p95    = sorted(totals)[min(int(0.95 * len(totals)), len(totals) - 1)]

        print(f"\n  📷 {img_name}")
        print(f"     total    median={statistics.median(totals):6.0f}ms  "
              f"p95={p95:6.0f}ms  mean={statistics.mean(totals):6.0f}ms")
        print(f"     encode   median={statistics.median(encs):6.0f}ms  "
              f"generate={statistics.median(infs):6.0f}ms")
        print(f'     "{runs[-1]["text"][:160]}"')

        size_data.append({
            "image": img_name, "resolution": f"{img_size}x{img_size}",
            "median_total_ms": round(statistics.median(totals)),
            "p95_total_ms": round(p95),
            "median_encode_ms": round(statistics.median(encs)),
            "median_generate_ms": round(statistics.median(infs)),
            "sample_output": runs[-1]["text"][:300],
        })
        all_results[f"{img_size}x{img_size}"] = size_data

    report = {
        "model": MODEL_ID, "revision": REVISION,
        "device": device,
        "gpu": torch.cuda.get_device_name(0) if device == "cuda" else None,
        "cold_start_s": round(load_s, 1),
        "max_new_tokens": MAX_NEW_TOKENS,
        "num_runs": NUM_RUNS,
        "results": all_results,
    }
    out = "D:/smart-glasses/benchmark_moondream_results.json"
    with open(out, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'=' * 62}")
    print(f"  ✅ DONE — cold start: {load_s:.1f}s  →  {out}")
    print(f"{'=' * 62}\n")


if __name__ == "__main__":
    main()
