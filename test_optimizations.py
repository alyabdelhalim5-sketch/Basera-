"""
test_optimizations.py
=====================
Test latency optimizations on Intel CPU:
1. Resolution reduction (384 -> 256 -> 192)
2. Token truncation (40 -> 20 -> 15 tokens)
3. PyTorch Dynamic INT8 Quantization
4. Thread count tuning (4, 6, 8, 12 threads)
"""

import os
import sys
import time
import statistics
from pathlib import Path
from PIL import Image
import torch
from transformers import AutoProcessor, AutoModelForImageTextToText

LOCAL_MODEL_PATH = r"D:\smart-glasses\hf_cache\smolvlm2_model"
TEST_IMAGE_PATH = r"D:\smart-glasses\test_images\street.jpg"

PROMPT_TEXT = (
    "You are a visual assistant for smart glasses. "
    "In ONE concise sentence, describe the scene. "
    "Prioritize obstacles, people, vehicles, or stairs."
)

MESSAGES = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {"type": "text", "text": PROMPT_TEXT},
        ],
    }
]

def load_local_model():
    print(f"Loading model from local path: {LOCAL_MODEL_PATH} ...")
    t0 = time.perf_counter()
    processor = AutoProcessor.from_pretrained(LOCAL_MODEL_PATH)
    model = AutoModelForImageTextToText.from_pretrained(
        LOCAL_MODEL_PATH,
        dtype=torch.float32,
        device_map="cpu"
    )
    model.eval()
    print(f"Model loaded in {time.perf_counter() - t0:.2f}s")
    return processor, model

def run_inference(processor, model, image, max_new_tokens=15):
    t0 = time.perf_counter()
    prompt = processor.apply_chat_template(MESSAGES, add_generation_prompt=True)
    inputs = processor(text=prompt, images=[image], return_tensors="pt")
    inputs = {k: v.to("cpu") if hasattr(v, "to") else v for k, v in inputs.items()}
    preprocess_ms = (time.perf_counter() - t0) * 1000

    t1 = time.perf_counter()
    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False,
            num_beams=1,
        )
    inference_ms = (time.perf_counter() - t1) * 1000

    t2 = time.perf_counter()
    text = processor.decode(output_ids[0], skip_special_tokens=True)
    for marker in ["assistant\n", "Assistant:", "ASSISTANT:"]:
        if marker.lower() in text.lower():
            text = text[text.lower().index(marker.lower()) + len(marker):].strip()
            break
    decode_ms = (time.perf_counter() - t2) * 1000

    total_ms = preprocess_ms + inference_ms + decode_ms
    new_tokens = len(output_ids[0]) - inputs["input_ids"].shape[1]
    tok_per_sec = (new_tokens / (inference_ms / 1000)) if inference_ms > 0 else 0

    return {
        "preprocess_ms": preprocess_ms,
        "inference_ms": inference_ms,
        "decode_ms": decode_ms,
        "total_ms": total_ms,
        "new_tokens": new_tokens,
        "tok_per_sec": tok_per_sec,
        "text": text.strip()
    }

def main():
    if not os.path.exists(TEST_IMAGE_PATH):
        print(f"Error: image not found at {TEST_IMAGE_PATH}")
        return

    orig_img = Image.open(TEST_IMAGE_PATH).convert("RGB")
    processor, fp32_model = load_local_model()

    print("\n" + "="*65)
    print(" EXPERIMENT 1: Token count impact (FP32, 384x384)")
    print("="*65)
    img_384 = orig_img.resize((384, 384), Image.LANCZOS)
    for max_tok in [15, 25]:
        res = run_inference(processor, fp32_model, img_384, max_new_tokens=max_tok)
        print(f"Max Tokens = {max_tok}:")
        print(f"  Total: {res['total_ms']:.0f} ms | Inf: {res['inference_ms']:.0f} ms | Gen Tokens: {res['new_tokens']} ({res['tok_per_sec']:.1f} tok/s)")
        print(f"  Output: \"{res['text']}\"")

    print("\n" + "="*65)
    print(" EXPERIMENT 2: Resolution impact (FP32, max_tokens=15)")
    print("="*65)
    for sz in [384, 256, 192]:
        resized = orig_img.resize((sz, sz), Image.LANCZOS)
        res = run_inference(processor, fp32_model, resized, max_new_tokens=15)
        print(f"Resolution {sz}x{sz}:")
        print(f"  Total: {res['total_ms']:.0f} ms | Inf: {res['inference_ms']:.0f} ms | Speed: {res['tok_per_sec']:.1f} tok/s")
        print(f"  Output: \"{res['text']}\"")

    print("\n" + "="*65)
    print(" EXPERIMENT 3: Dynamic INT8 Quantization (torch.ao.quantization)")
    print("="*65)
    print("Quantizing linear layers to qint8...")
    t_q0 = time.perf_counter()
    int8_model = torch.ao.quantization.quantize_dynamic(
        fp32_model,
        {torch.nn.Linear},
        dtype=torch.qint8
    )
    print(f"Quantized in {time.perf_counter() - t_q0:.2f}s")

    for sz in [256, 192]:
        resized = orig_img.resize((sz, sz), Image.LANCZOS)
        res = run_inference(processor, int8_model, resized, max_new_tokens=15)
        print(f"INT8 Model @ {sz}x{sz} (max_tokens=15):")
        print(f"  Total: {res['total_ms']:.0f} ms | Inf: {res['inference_ms']:.0f} ms | Speed: {res['tok_per_sec']:.1f} tok/s")
        print(f"  Output: \"{res['text']}\"")

    # Save results summary
    print("\nTesting complete.")

if __name__ == "__main__":
    main()
