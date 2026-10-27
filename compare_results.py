"""
compare_results.py — Stage 2 Summary
=====================================
After running both benchmarks, this prints a side-by-side comparison table.

Usage:
    python compare_results.py
"""

import json
from pathlib import Path


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def fmt(val, unit="ms"):
    if val is None:
        return "N/A"
    return f"{val}{unit}"


def main():
    smol = load("D:/smart-glasses/benchmark_results.json")
    moon = load("D:/smart-glasses/benchmark_moondream_results.json")

    print("\n" + "=" * 72)
    print("  Side-by-Side Comparison: SmolVLM2-500M  vs  Moondream 0.5B")
    print("=" * 72)

    for res in ["384x384", "512x512"]:
        print(f"\n  Resolution: {res}  |  max_new_tokens=40  |  10 warm runs")
        print(f"  {'Metric':<28} {'SmolVLM2-500M':>18} {'Moondream-0.5B':>18}")
        print(f"  {'─'*28} {'─'*18} {'─'*18}")

        def get(data, key):
            if data is None:
                return None
            rows = data.get("results", {}).get(res, [])
            return rows[0].get(key) if rows else None

        rows = [
            ("Cold start (s)", "cold_start_s", "s"),
            ("Median total (ms)", f"median_total_ms", "ms"),
            ("p95 total (ms)",    f"p95_total_ms",    "ms"),
        ]

        smol_cs = smol.get("cold_start_s") if smol else None
        moon_cs = moon.get("cold_start_s") if moon else None

        def row(label, key, unit):
            if key == "cold_start_s":
                sv = f"{smol_cs}{unit}" if smol_cs else "N/A"
                mv = f"{moon_cs}{unit}" if moon_cs else "N/A"
            else:
                sv_raw = get(smol, key)
                mv_raw = get(moon, key)
                sv = f"{sv_raw}{unit}" if sv_raw else "N/A"
                mv = f"{mv_raw}{unit}" if mv_raw else "N/A"
            print(f"  {label:<28} {sv:>18} {mv:>18}")

        for label, key, unit in rows:
            row(label, key, unit)

        # Outputs
        smol_out = get(smol, "sample_output") or "N/A"
        moon_out = get(moon, "sample_output") or "N/A"
        print(f"\n  SmolVLM2 output: {smol_out[:120]}")
        print(f"  Moondream output: {moon_out[:120]}")

    print(f"\n{'=' * 72}")
    print("  Recommendation: pick the model with lower p95 AND acceptable output quality.")
    print("=" * 72 + "\n")


if __name__ == "__main__":
    main()
