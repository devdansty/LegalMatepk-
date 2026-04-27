"""
Language Detection Module
Detects script types (Urdu/Arabic, English, etc.) in images for smart OCR routing
"""

import cv2
import numpy as np
import re

# Unicode ranges for script detection
URDU_ARABIC_RANGE = range(0x0600, 0x06FF + 1)  # Arabic Unicode block
ENGLISH_ASCII_RANGE = range(0x0020, 0x007F)     # ASCII printable range

def detect_script_from_text(text: str) -> dict:
    """
    Detect script composition in extracted text.
    Returns: {
        "urdu_ratio": float (0-1),
        "english_ratio": float (0-1),
        "primary_script": str ("urdu", "english", "mixed")
    }
    """
    if not text:
        return {
            "urdu_ratio": 0,
            "english_ratio": 0,
            "primary_script": "unknown"
        }
    
    urdu_chars = sum(1 for c in text if ord(c) in URDU_ARABIC_RANGE)
    english_chars = sum(1 for c in text if ord(c) in ENGLISH_ASCII_RANGE)
    total_chars = len(text)
    
    urdu_ratio = urdu_chars / total_chars if total_chars > 0 else 0
    english_ratio = english_chars / total_chars if total_chars > 0 else 0
    
    # Determine primary script
    if urdu_ratio >= 0.6:
        primary = "urdu"
    elif english_ratio >= 0.6:
        primary = "english"
    else:
        primary = "mixed"
    
    return {
        "urdu_ratio": round(urdu_ratio, 3),
        "english_ratio": round(english_ratio, 3),
        "primary_script": primary
    }


def analyze_image_layout(image: np.ndarray) -> dict:
    """
    Analyze image layout for complexity hints.
    Returns: {
        "has_tables": bool,
        "has_multiple_columns": bool,
        "complexity_score": float (0-1)
    }
    """
    try:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Edge detection
        edges = cv2.Canny(gray, 100, 200)
        
        # Detect lines (tables/columns often have clear lines)
        lines = cv2.HoughLinesP(edges, 1, np.pi/180, 50, minLineLength=100, maxLineGap=10)
        has_tables = lines is not None and len(lines) > 20
        
        # Detect vertical lines for column detection
        vertical_lines = 0
        if lines is not None:
            for line in lines:
                x1, y1, x2, y2 = line[0]
                if abs(x2 - x1) < 20:  # Nearly vertical
                    vertical_lines += 1
        
        has_multiple_columns = vertical_lines > 5
        
        # Complexity = combination of line density + edge density
        edge_density = cv2.countNonZero(edges) / (gray.size / 255)
        complexity = min(1.0, edge_density * (len(lines) or 10) / 100 if lines is not None else 0.3)
        
        return {
            "has_tables": has_tables,
            "has_multiple_columns": has_multiple_columns,
            "complexity_score": round(complexity, 3),
            "line_count": len(lines) if lines is not None else 0
        }
    except Exception as e:
        print(f"[LANGUAGE_DETECTOR] Error analyzing layout: {e}")
        return {
            "has_tables": False,
            "has_multiple_columns": False,
            "complexity_score": 0.5,
            "line_count": 0
        }


def should_use_vision_ai(
    language_analysis: dict,
    confidence: float,
    layout_analysis: dict
) -> tuple[bool, str]:
    """
    Determine if Vision AI should be used based on:
    - Language composition (Urdu detected)
    - PaddleOCR confidence score
    - Document complexity
    
    Returns: (use_vision_ai: bool, reason: str)
    """
    
    # 1. Always use Vision AI for Urdu-heavy or mixed documents
    if language_analysis["primary_script"] in ["urdu", "mixed"]:
        return True, f"Detected {language_analysis['primary_script']} script ({language_analysis['urdu_ratio']*100:.0f}% Urdu)"
    
    # 2. Use Vision AI if PaddleOCR confidence is low
    if confidence < 0.65:
        return True, f"Low PaddleOCR confidence ({confidence:.2f} < 0.65 threshold)"
    
    # 3. Use Vision AI for complex layouts (tables, multiple columns, etc.)
    if layout_analysis["complexity_score"] > 0.7:
        return (
            True,
            f"Complex document layout (complexity: {layout_analysis['complexity_score']:.2f}, tables: {layout_analysis['has_tables']}, columns: {layout_analysis['has_multiple_columns']})"
        )
    
    # 4. English text with good confidence → use PaddleOCR (save costs)
    return False, "Using PaddleOCR (English text, high confidence, simple layout)"
