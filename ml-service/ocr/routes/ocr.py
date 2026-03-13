from fastapi import APIRouter, UploadFile, File, HTTPException
from services.ocr_engine import extract_text_from_image
import traceback

router = APIRouter()

@router.post("/extract")
async def extract_ocr(file: UploadFile = File(...)):
    try:
        print(f"[OCR_ROUTE] Received file: {file.filename}, Content-Type: {file.content_type}")
        
        # Check if it's an image by either content-type or file extension
        is_image_by_type = file.content_type and file.content_type.startswith("image")
        is_image_by_ext = file.filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'))
        
        if not (is_image_by_type or is_image_by_ext):
            raise HTTPException(status_code=400, detail=f"File must be an image. Got: {file.content_type}")

        contents = await file.read()
        print(f"[OCR_ROUTE] File size: {len(contents)} bytes")
        
        text, confidence = extract_text_from_image(contents)
        
        print(f"[OCR_ROUTE] Extraction successful. Text length: {len(text)}")

        return {
            "success": True,
            "raw_text": text,
            "confidence": confidence
        }

    except HTTPException as http_exc:
        print(f"[OCR_ROUTE] HTTP Exception: {http_exc.detail}")
        raise http_exc
    except Exception as e:
        print(f"[OCR_ROUTE] Exception: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))