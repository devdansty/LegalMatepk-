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

# Initialize OCR with the URDU model (which also handles basic English)
ocr = PaddleOCR(
    use_angle_cls=True,
    lang="en" 
)

def extract_text_from_image(image_bytes: bytes):
    try:
        # Pass the raw image first. Deep learning models prefer raw RGB data.
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            raise ValueError("Failed to decode image - invalid image data")

        # Let PaddleOCR handle the raw image
        result = ocr.ocr(img)

        extracted_text = []
        confidences = []

        # Handle the case where result might be None if no text is found
        if result and result[0]: 
            for line in result[0]: # PaddleOCR v2.6+ wraps results in an extra list
                text = line[1][0]
                conf = line[1][1]
                extracted_text.append(text)
                confidences.append(conf)

        full_text = "\n".join(extracted_text)
        avg_conf = round(sum(confidences)/len(confidences), 3) if confidences else 0

        print(f"[OCR_ENGINE] Successfully extracted {len(extracted_text)} text blocks. Confidence: {avg_conf}")
        return full_text, avg_conf

    except Exception as e:
        print(f"[OCR_ENGINE] Error processing image: {str(e)}")
        print(traceback.format_exc())
        raise RuntimeError(f"OCR processing failed: {str(e)}")