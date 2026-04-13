from fastapi import APIRouter, UploadFile, File, HTTPException
from services.ocr_engine import extract_text_from_image
from services.vision_ai import get_vision_api_stats
import traceback

router = APIRouter()

@router.post("/extract")
async def extract_ocr(file: UploadFile = File(...)):
    """
    Hybrid OCR endpoint - intelligently routes between PaddleOCR and Vision AI.
    
    Decision factors:
    - Urdu/Arabic script detected → Vision AI
    - Mixed language → Vision AI  
    - Low confidence (<0.65) → Vision AI
    - Complex layout (tables, columns) → Vision AI
    - English + high confidence + simple layout → PaddleOCR (cost savings)
    """
    try:
        print(f"[OCR_ROUTE] Received file: {file.filename}, Content-Type: {file.content_type}")
        
        # Check if it's an image by either content-type or file extension
        is_image_by_type = file.content_type and file.content_type.startswith("image")
        is_image_by_ext = file.filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'))
        
        if not (is_image_by_type or is_image_by_ext):
            raise HTTPException(status_code=400, detail=f"File must be an image. Got: {file.content_type}")

        contents = await file.read()
        print(f"[OCR_ROUTE] File size: {len(contents)} bytes")
        
        # Step 1: Run hybrid OCR extraction
        text, confidence, engine_used, metadata = extract_text_from_image(contents)
        
        print(f"[OCR_ROUTE] ✅ Extraction successful using {engine_used}. Text length: {len(text)}")

        return {
            "success": True,
            "raw_text": text,
            "confidence": confidence,
            "engine_used": engine_used,
            "language": metadata.get("language_analysis", {}).get("primary_script", "unknown"),
            "routing_reason": metadata.get("routing_decision", ""),
            "metadata": metadata
        }

    except HTTPException as http_exc:
        print(f"[OCR_ROUTE] HTTP Exception: {http_exc.detail}")
        raise http_exc
    except Exception as e:
        print(f"[OCR_ROUTE] ❌ Exception: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_ocr_stats():
    """Get OCR system statistics including Vision API usage"""
    vision_stats = get_vision_api_stats()
    
    return {
        "ocr_system": "hybrid (PaddleOCR + Vision AI)",
        "vision_api_stats": vision_stats,
        "routing_logic": {
            "priority_1": "Detect language and layout with PaddleOCR",
            "priority_2": "Use Vision AI if: Urdu detected OR mixed language OR confidence < 0.65 OR complexity > 0.7",
            "priority_3": "Fallback to PaddleOCR if Vision AI fails",
            "cost_optimization": "PaddleOCR for 70-80% of requests (English only), Vision AI for complex/multilingual (20-30%)"
        }
    }
