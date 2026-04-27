"""
Google Cloud Vision AI Integration
Handles OCR for Urdu, complex documents, and low-confidence scenarios
Uses REST API with API Key (not service account)
"""

import base64
import requests
import os
import time

GOOGLE_VISION_ENDPOINT = "https://vision.googleapis.com/v1/images:annotate"

# Rate limiting
VISION_API_DAILY_REQUESTS = {"count": 0, "timestamp": time.time()}
VISION_API_MAX_DAILY = int(os.getenv("VISION_API_DAILY_LIMIT", "1000"))


def extract_text_with_vision_ai(image_bytes: bytes) -> tuple[str, float]:
    """
    Extract text using Google Cloud Vision API.
    
    Returns:
        (extracted_text: str, confidence: float)
    
    Raises:
        RuntimeError: If API call fails or credentials missing
    """
    
    google_vision_api_key = os.getenv("GOOGLE_VISION_API_KEY")

    if not google_vision_api_key:
        raise RuntimeError(
            "GOOGLE_VISION_API_KEY not set. "
            "Set environment variable: export GOOGLE_VISION_API_KEY='your-api-key'"
        )
    
    # Check daily limit
    current_time = time.time()
    if current_time - VISION_API_DAILY_REQUESTS["timestamp"] > 86400:  # 24 hours
        VISION_API_DAILY_REQUESTS["count"] = 0
        VISION_API_DAILY_REQUESTS["timestamp"] = current_time
    
    if VISION_API_DAILY_REQUESTS["count"] >= VISION_API_MAX_DAILY:
        raise RuntimeError(
            f"Daily Vision API limit reached ({VISION_API_MAX_DAILY}). "
            f"Resets in {86400 - (current_time - VISION_API_DAILY_REQUESTS['timestamp']):.0f}s"
        )
    
    try:
        # Encode image to base64
        image_content = base64.b64encode(image_bytes).decode("utf-8")
        
        # Build request payload
        payload = {
            "requests": [
                {
                    "image": {
                        "content": image_content
                    },
                    "features": [
                        {
                            "type": "DOCUMENT_TEXT_DETECTION"  # Best for documents (handles complex layouts)
                        },
                        {
                            "type": "TEXT_DETECTION"  # Fallback for natural scenes
                        }
                    ],
                    "imageContext": {
                        "languageHints": ["ur", "en", "ar"]  # Urdu, English, Arabic
                    }
                }
            ]
        }
        
        # Make API call
        start_time = time.time()
        response = requests.post(
            f"{GOOGLE_VISION_ENDPOINT}?key={google_vision_api_key}",
            json=payload,
            timeout=30
        )
        elapsed = time.time() - start_time
        
        print(f"[VISION_AI] API response in {elapsed:.2f}s")
        
        if response.status_code != 200:
            error_detail = response.json().get("error", {}).get("message", response.text)
            raise RuntimeError(f"Vision API error ({response.status_code}): {error_detail}")
        
        # Increment counter
        VISION_API_DAILY_REQUESTS["count"] += 1
        
        # Parse response
        result = response.json()
        responses = result.get("responses", [])
        
        if not responses:
            return "", 0.0
        
        # Extract text using DOCUMENT_TEXT_DETECTION (preferred for documents)
        text_annotations = responses[0].get("fullTextAnnotation", {})
        extracted_text = text_annotations.get("text", "")
        
        # Estimate confidence from response (Vision API doesn't always provide explicit confidence)
        # Use presence of text and number of pages as proxy
        pages = text_annotations.get("pages", [])
        confidence = 0.9 if extracted_text and pages else 0.5
        
        print(f"[VISION_AI] Extracted {len(extracted_text)} characters. "
              f"Confidence: {confidence:.2f}. Daily requests: {VISION_API_DAILY_REQUESTS['count']}/{VISION_API_MAX_DAILY}")
        
        if not extracted_text:
            print("[VISION_AI] Warning: No text extracted by DOCUMENT_TEXT_DETECTION, trying TEXT_DETECTION...")
            # Fallback to TEXT_DETECTION results
            text_detections = responses[0].get("textAnnotations", [])
            extracted_text = "\n".join([anno.get("description", "") for anno in text_detections[1:]])  # Skip first (full match)
            confidence = 0.7 if extracted_text else 0.0
        
        return extracted_text, confidence
    
    except requests.exceptions.Timeout:
        raise RuntimeError("Vision API request timed out (>30s)")
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Vision API request failed: {str(e)}")


def get_vision_api_stats() -> dict:
    """Get current Vision API usage statistics"""
    current_time = time.time()
    reset_in = max(0, 86400 - (current_time - VISION_API_DAILY_REQUESTS["timestamp"]))
    
    return {
        "daily_requests": VISION_API_DAILY_REQUESTS["count"],
        "daily_limit": VISION_API_MAX_DAILY,
        "remaining": VISION_API_MAX_DAILY - VISION_API_DAILY_REQUESTS["count"],
        "resets_in_seconds": int(reset_in),
        "configured": bool(os.getenv("GOOGLE_VISION_API_KEY"))
    }
