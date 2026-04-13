from fastapi import FastAPI
from routes.ocr import router as ocr_router
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

app = FastAPI(
    title="LegalMate OCR Service",
    version="1.0.0",
    description="OCR processing service for LegalMate"
)

# Health check
@app.get("/")
def root():
    return {
        "status": "LegalMate AI running",
        "vision_api_configured": bool(os.getenv("GOOGLE_VISION_API_KEY")),
        "vision_api_daily_limit": os.getenv("VISION_API_DAILY_LIMIT", "1000")
    }

# Register routes
app.include_router(ocr_router, prefix="/ocr")