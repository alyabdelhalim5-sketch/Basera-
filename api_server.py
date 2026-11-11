"""
Basera AI - FastAPI Backend Server
====================================
Bridge between Flutter mobile app and the SmolVLM2 pipeline.
Run with: D:\smart-glasses\venv\Scripts\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000
"""

import io
import time
import logging
import traceback
from pathlib import Path
from contextlib import asynccontextmanager
from PIL import Image

from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# ─── Logging ────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("basera-api")

# ─── Import our existing pipeline (do NOT modify pipeline.py) ────────────────
import sys
sys.path.insert(0, str(Path(__file__).parent))
from pipeline import SmartGlassesPipeline

# ─── Global pipeline singleton ───────────────────────────────────────────────
MODEL_PATH = Path(__file__).parent / "hf_cache" / "smolvlm2_model"
pipeline_instance: SmartGlassesPipeline | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, release on shutdown."""
    global pipeline_instance
    log.info("🚀 Starting Basera API Server …")
    log.info(f"📦 Loading model from: {MODEL_PATH}")
    try:
        pipeline_instance = SmartGlassesPipeline(
            model_path=str(MODEL_PATH),
            target_resolution=256,
            max_new_tokens=120,          # more tokens → richer descriptions
        )
        pipeline_instance.initialize()
        log.info("✅ Model loaded and warm — ready for requests.")
    except Exception as e:
        log.error(f"❌ Failed to load model: {e}")
        log.error(traceback.format_exc())
        pipeline_instance = None
    yield
    log.info("🛑 Shutting down Basera API Server.")


# ─── FastAPI App ─────────────────────────────────────────────────────────────
app = FastAPI(
    title="Basera AI Backend",
    description="SmolVLM2 scene-description API for the Basera Flutter app",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Endpoints ───────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Flutter calls this to verify the server is reachable and model is ready."""
    if pipeline_instance is None:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "message": "Model not loaded"},
        )
    return {
        "status": "ok",
        "model": "SmolVLM2-500M-Video-Instruct",
        "model_path": str(MODEL_PATH),
        "ready": True,
    }


@app.post("/describe")
async def describe(
    image: UploadFile = File(..., description="JPEG image from phone camera"),
    language: str = Form(default="ar", description="'ar' for Arabic, 'en' for English"),
    max_tokens: int = Form(default=120, description="Max tokens for description"),
    force: bool = Form(default=False, description="Skip change-detection, always infer"),
):
    """
    Main endpoint: receive image → run SmolVLM2 → return description.

    Returns JSON:
    {
        "description": "...",
        "scene_changed": true,
        "inference_ms": 25432,
        "total_latency_ms": 25500,
        "language": "ar",
        "skipped": false
    }
    """
    if pipeline_instance is None:
        raise HTTPException(status_code=503, detail="Model is not loaded. Check server logs.")

    t_start = time.perf_counter()

    # ── Read image bytes ──────────────────────────────────────────────────────
    try:
        raw = await image.read()
        pil_img = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}")

    log.info(f"📸 Received image {pil_img.size} from Flutter (lang={language})")

    # ── Optionally override pipeline token count ──────────────────────────────
    original_tokens = pipeline_instance.max_new_tokens
    if max_tokens != original_tokens:
        pipeline_instance.max_new_tokens = max_tokens

    # ── Override CHAT_MESSAGES prompt based on language ──────────────────────
    import pipeline as _pl
    _original_messages = _pl.CHAT_MESSAGES
    if language == "ar":
        _pl.CHAT_MESSAGES = [
            {
                "role": "user",
                "content": [
                    {"type": "image"},
                    {"type": "text", "text": (
                        "صف ما تراه في هذه الصورة باللغة العربية بوضوح وتفصيل. "
                        "اذكر الأشخاص والأشياء والبيئة المحيطة وأي عقبات أو مخاطر."
                    )},
                ],
            }
        ]
    else:
        _pl.CHAT_MESSAGES = [
            {
                "role": "user",
                "content": [
                    {"type": "image"},
                    {"type": "text", "text": (
                        "Describe this scene clearly and helpfully for a visually impaired person. "
                        "Mention people, objects, environment, obstacles, and any hazards."
                    )},
                ],
            }
        ]

    # ── Run inference ─────────────────────────────────────────────────────────
    try:
        result = pipeline_instance.process_image(
            image_input=pil_img,
            trigger_tts=False,       # TTS handled by Flutter flutter_tts
        )
    except Exception as e:
        log.error(f"❌ Inference error: {e}")
        log.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Inference failed: {e}")
    finally:
        pipeline_instance.max_new_tokens = original_tokens   # restore
        import pipeline as _pl2                               # restore CHAT_MESSAGES
        _pl2.CHAT_MESSAGES = _original_messages

    t_total = (time.perf_counter() - t_start) * 1000

    description = result.get("description", "")
    scene_changed = result.get("scene_changed", True)
    inference_ms = result.get("inference_ms", 0)

    # ── If scene didn't change and not forced, tell Flutter to skip TTS ───────
    skipped = not scene_changed and not force

    log.info(
        f"✅ Done — changed={scene_changed}, skipped={skipped}, "
        f"infer={inference_ms:.0f}ms, total={t_total:.0f}ms"
    )
    log.info(f"📝 Description: {description[:80]}…" if len(description) > 80 else f"📝 {description}")

    return {
        "description": description,
        "scene_changed": scene_changed,
        "skipped": skipped,
        "inference_ms": round(inference_ms),
        "total_latency_ms": round(t_total),
        "language": language,
    }


@app.post("/reset")
async def reset_scene():
    """Force pipeline to forget last frame (treat next frame as changed)."""
    if pipeline_instance is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    pipeline_instance.prev_image = None
    return {"status": "ok", "message": "Scene hash cleared"}


@app.get("/status")
async def status():
    """Extended status for debugging from Flutter settings screen."""
    if pipeline_instance is None:
        return {"ready": False, "model_loaded": False}
    return {
        "ready": True,
        "model_loaded": True,
        "model_path": str(MODEL_PATH),
        "max_new_tokens": pipeline_instance.max_new_tokens,
        "target_resolution": pipeline_instance.target_resolution,
        "has_last_frame": pipeline_instance.prev_image is not None,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api_server:app", host="0.0.0.0", port=8000, reload=False, log_level="info")
