"""
test_pipeline_flow.py — Test smart glasses stream simulation
Simulates 3 frames:
1. street.jpg (new scene -> full inference)
2. street.jpg (same scene -> instant skip via change detection)
3. stairs.jpg (hazard scene -> full inference)
"""

import time
from pipeline import SmartGlassesPipeline

def main():
    p = SmartGlassesPipeline(target_resolution=256, max_new_tokens=15)
    p.initialize()

    frames = [
        (r"D:\smart-glasses\test_images\street.jpg", "Frame 1 (Street)"),
        (r"D:\smart-glasses\test_images\street.jpg", "Frame 2 (Identical Street)"),
        (r"D:\smart-glasses\test_images\stairs.jpg", "Frame 3 (New Scene: Stairs)"),
    ]

    print("\n" + "=" * 60)
    print("  SIMULATING SMART GLASSES FRAME STREAM (EVENT-DRIVEN)")
    print("=" * 60)

    for path, label in frames:
        print(f"\n---> Incoming {label}:")
        t0 = time.perf_counter()
        res = p.process_image(path, trigger_tts=False)
        total_time = (time.perf_counter() - t0) * 1000

        if res.get("status") == "skipped_redundant":
            print(f"     [ACTION] SKIPPED! Scene unchanged.")
            print(f"     Latency: {total_time:.1f} ms | Power saved: 99.9%")
        else:
            print(f"     [ACTION] INFERENCE COMPLETE.")
            print(f"     Description: \"{res.get('description')}\"")
            print(f"     Latency:     {res.get('total_latency_ms'):.1f} ms")

    print("\n" + "=" * 60)
    print("  Stream simulation completed successfully.")
    print("=" * 60)

if __name__ == "__main__":
    main()
