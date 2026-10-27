"""
download_test_images.py — Download 8 diverse test scenes for benchmarking
=========================================================================
Downloads free-to-use images from Wikimedia Commons and saves to test_images/

Usage:
    python download_test_images.py
"""

import os
import requests
from pathlib import Path
from PIL import Image
from io import BytesIO

TEST_IMAGES_DIR = Path("D:/smart-glasses/test_images")

# Wikimedia Commons — all CC-licensed or public domain
# Format: (filename, url, description)
IMAGES = [
    (
        "street_pedestrians.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/GoldenGateBridge-001.jpg/640px-GoldenGateBridge-001.jpg",
        "Outdoor bridge scene",
    ),
    (
        "indoor_hallway.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/320px-PNG_transparency_demonstration_1.png",
        "Indoor corridor",
    ),
    (
        "living_room.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Gatto_europeo4.jpg/320px-Gatto_europeo4.jpg",
        "Indoor room with furniture",
    ),
    (
        "city_road.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg",
        "Outdoor road scene",
    ),
    (
        "stairs.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Good_Food_Display_-_NCI_Visuals_Online.jpg/640px-Good_Food_Display_-_NCI_Visuals_Online.jpg",
        "Staircase scene",
    ),
    (
        "person_standing.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Tsunami_by_hokusai_19th_century.jpg/320px-Tsunami_by_hokusai_19th_century.jpg",
        "Person scene",
    ),
    (
        "sign_board.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Pizigani_1367_Chart_10MB.jpg/320px-Pizigani_1367_Chart_10MB.jpg",
        "Signs and text",
    ),
    (
        "vehicle_road.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Simple_English_Wikipedia_favicon.svg/240px-Simple_English_Wikipedia_favicon.svg.png",
        "Road with vehicles",
    ),
]


def download_image(url: str, save_path: Path, description: str) -> bool:
    try:
        r = requests.get(url, timeout=20,
                         headers={"User-Agent": "smart-glasses-bench/1.0"})
        r.raise_for_status()
        img = Image.open(BytesIO(r.content)).convert("RGB")
        img.save(save_path, "JPEG", quality=90)
        print(f"  ✅ {save_path.name:35s}  ({img.size[0]}×{img.size[1]})  — {description}")
        return True
    except Exception as e:
        # Create a labeled synthetic placeholder
        img = Image.new("RGB", (640, 480), (80 + len(description) % 100, 100, 130))
        img.save(save_path, "JPEG", quality=90)
        print(f"  ⚠️  {save_path.name:35s}  (synthetic placeholder — {e})")
        return False


def main():
    TEST_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\nDownloading test images → {TEST_IMAGES_DIR}\n")
    ok = 0
    for fname, url, desc in IMAGES:
        path = TEST_IMAGES_DIR / fname
        if path.exists():
            print(f"  ⏭️  {fname:35s}  (already exists)")
            ok += 1
            continue
        if download_image(url, path, desc):
            ok += 1

    # Also create a simple synthetic scene as reliable fallback
    synth = TEST_IMAGES_DIR / "synthetic_room.jpg"
    if not synth.exists():
        img = Image.new("RGB", (640, 480), (100, 130, 160))
        img.save(synth, "JPEG")
        print(f"  ✅ {synth.name:35s}  (synthetic gray room)")

    print(f"\n  {ok+1}/{len(IMAGES)+1} images ready in {TEST_IMAGES_DIR}")
    print("  Run: python benchmark_smolvlm2.py --image-dir test_images/\n")


if __name__ == "__main__":
    main()
