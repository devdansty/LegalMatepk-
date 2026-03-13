from fastapi import FastAPI
from routes.ocr import router as ocr_router

app = FastAPI(
    title="LegalMate OCR Service",
    version="1.0.0",
    description="OCR processing service for LegalMate"
)

# Health check
@app.get("/")
def root():
    return {"status": "LegalMate AI running"}

# Register routes
app.include_router(ocr_router, prefix="/ocr")