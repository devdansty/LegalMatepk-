# import numpy as np
# import cv2
# from paddleocr import PaddleOCR

# # Initialize OCR once (important for performance)
# ocr = PaddleOCR(
#     use_angle_cls=True,
#     lang="en"   # Arabic model = BEST for Urdu
# )

# def extract_text_from_image(image_bytes: bytes):
#     try:
#         processed_img = preprocess_image(image_bytes)
#         result = ocr.ocr(processed_img)

#         extracted_text = []
#         confidences = []

#         for line in result:
#             if line:
#                 for word_info in line:
#                     text = word_info[1][0]
#                     conf = word_info[1][1]
#                     extracted_text.append(text)
#                     confidences.append(conf)

#         full_text = "\n".join(extracted_text)
#         avg_conf = round(sum(confidences)/len(confidences), 3) if confidences else 0

#         return full_text, avg_conf

#     except Exception as e:
#         raise RuntimeError(f"OCR processing failed: {str(e)}")
    
# def preprocess_image(image_bytes: bytes):
#     # Convert bytes → OpenCV image
#     nparr = np.frombuffer(image_bytes, np.uint8)
#     img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

#     # 1️⃣ Convert to grayscale
#     gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

#     # 2️⃣ Contrast enhancement using CLAHE
#     clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
#     contrast = clahe.apply(gray)

#     # 3️⃣ Mild denoise (removes camera grain)
#     denoised = cv2.fastNlMeansDenoising(contrast, h=10)

#     # 4️⃣ Light sharpening (improves Urdu clarity)
#     kernel = np.array([[0, -1, 0],
#                        [-1, 5,-1],
#                        [0, -1, 0]])
#     sharpened = cv2.filter2D(denoised, -1, kernel)

#     return sharpened


import numpy as np
import cv2
from paddleocr import PaddleOCR
import traceback
import time

from .language_detector import (
    detect_script_from_text,
    analyze_image_layout,
    should_use_vision_ai
)
from .vision_ai import extract_text_with_vision_ai

# Initialize PaddleOCR once (important for performance)
ocr = PaddleOCR(
    use_angle_cls=True,
    lang="en"
)


def extract_text_with_paddle(image_bytes: bytes) -> tuple[str, float]:
    """
    Extract text using PaddleOCR (fast, free, good for English).
    
    Returns:
        (extracted_text: str, confidence: float)
    """
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            raise ValueError("Failed to decode image - invalid image data")

        result = ocr.ocr(img)

        extracted_text = []
        confidences = []

        if result and result[0]:
            for line in result[0]:
                text = line[1][0]
                conf = line[1][1]
                extracted_text.append(text)
                confidences.append(conf)

        full_text = "\n".join(extracted_text)
        avg_conf = round(sum(confidences) / len(confidences), 3) if confidences else 0

        return full_text, avg_conf

    except Exception as e:
        print(f"[OCR_ENGINE] PaddleOCR error: {str(e)}")
        raise RuntimeError(f"PaddleOCR processing failed: {str(e)}")


def extract_text_from_image(image_bytes: bytes) -> tuple[str, float, str, dict]:
    """
    HYBRID OCR Engine - intelligently routes between PaddleOCR and Vision AI.
    
    Decision Logic:
    1. Try PaddleOCR (fast, free)
    2. Analyze language/layout
    3. If Urdu detected OR mixed OR low confidence OR complex layout → use Vision AI
    4. Return best result
    
    Returns:
        (extracted_text: str, confidence: float, engine_used: str, metadata: dict)
    """
    
    start_time = time.time()
    
    try:
        # Decode image for analysis
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            raise ValueError("Failed to decode image - invalid image data")

        print("[OCR_ENGINE] ✓ Image decoded successfully")

        # Step 1: Quick PaddleOCR extraction
        print("[OCR_ENGINE] Step 1/4: Running PaddleOCR...")
        paddle_text, paddle_conf = extract_text_with_paddle(image_bytes)
        print(f"[OCR_ENGINE] PaddleOCR: {len(paddle_text)} chars, confidence: {paddle_conf:.2f}")

        # Step 2: Analyze extracted text for language
        print("[OCR_ENGINE] Step 2/4: Analyzing language composition...")
        language_analysis = detect_script_from_text(paddle_text)
        print(f"[OCR_ENGINE] Language: {language_analysis['primary_script']} "
              f"(Urdu: {language_analysis['urdu_ratio']*100:.0f}%, English: {language_analysis['english_ratio']*100:.0f}%)")

        # Step 3: Analyze image layout complexity
        print("[OCR_ENGINE] Step 3/4: Analyzing document layout...")
        layout_analysis = analyze_image_layout(img)
        print(f"[OCR_ENGINE] Layout complexity: {layout_analysis['complexity_score']:.2f} "
              f"(tables: {layout_analysis['has_tables']}, columns: {layout_analysis['has_multiple_columns']})")

        # Step 4: Decide which engine to use
        print("[OCR_ENGINE] Step 4/4: Routing decision...")
        use_vision, routing_reason = should_use_vision_ai(language_analysis, paddle_conf, layout_analysis)

        metadata = {
            "language_analysis": language_analysis,
            "layout_analysis": layout_analysis,
            "routing_decision": routing_reason,
            "paddle_confidence": paddle_conf
        }

        if use_vision:
            print(f"[OCR_ENGINE] 🔄 Escalating to Vision AI: {routing_reason}")
            try:
                vision_text, vision_conf = extract_text_with_vision_ai(image_bytes)
                elapsed = time.time() - start_time
                print(f"[OCR_ENGINE] ✅ Hybrid extraction complete in {elapsed:.2f}s using Vision AI")
                metadata["vision_confidence"] = vision_conf
                metadata["paddle_skipped_reason"] = routing_reason
                return vision_text, vision_conf, "vision_ai", metadata
            except Exception as e:
                print(f"[OCR_ENGINE] ⚠️ Vision AI failed, falling back to PaddleOCR: {str(e)}")
                metadata["vision_error"] = str(e)
                elapsed = time.time() - start_time
                print(f"[OCR_ENGINE] ✅ Hybrid extraction complete in {elapsed:.2f}s using PaddleOCR (fallback)")
                return paddle_text, paddle_conf, "paddle_ocr", metadata
        else:
            print(f"[OCR_ENGINE] ✅ Using PaddleOCR: {routing_reason}")
            elapsed = time.time() - start_time
            print(f"[OCR_ENGINE] ✅ Hybrid extraction complete in {elapsed:.2f}s using PaddleOCR")
            return paddle_text, paddle_conf, "paddle_ocr", metadata

    except Exception as e:
        print(f"[OCR_ENGINE] ❌ Critical error in hybrid extraction: {str(e)}")
        print(traceback.format_exc())
        raise RuntimeError(f"OCR processing failed: {str(e)}")