import express from "express";
import multer from "multer";
import { requireAuth, requireNotGuest } from "../../shared/middleware/auth.js";
import {
  handleDocumentSummarization,
  getOCRResult,
  getUserOCRHistory,
  deleteOCRResult
} from "./ocr.controller.js";

const router = express.Router();

// Configure multer for file uploads (store in memory)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 25 * 1024 * 1024 // 25 MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "application/octet-stream" // Allow generic type, will validate by extension
    ];

    const allowedExtensions = ['.jpg', '.jpeg', '.png'];
    const fileExtension = file.originalname.toLowerCase().match(/\.[^.]*$/)?.[0];

    const validMime = allowedMimes.includes(file.mimetype);
    const validExtension = fileExtension && allowedExtensions.includes(fileExtension);

    if (validMime && validExtension) {
      cb(null, true);
    } else {
      cb(new Error(`File type not supported. Allowed: JPG, JPEG, PNG (received: ${file.mimetype}, ${fileExtension})`));
    }
  }
});

/**
 * POST /api/ocr
 * Main endpoint for document summarization
 * Requires:
 *   - Authorization header with Bearer token (authenticated users only, NOT guests)
 *   - File upload (multipart/form-data) with field name "document"
 *   - Optional: "query" field in the request body for custom summarization query
 *
 * Returns:
 *   - Extracted text from the document
 *   - Generated summary
 *   - Processing metadata (response times)
 */
router.post("/", requireAuth(), requireNotGuest(), upload.single("document"), handleDocumentSummarization);

/**
 * GET /api/ocr/:ocrResultId
 * Retrieve a specific OCR result by ID
 * Requires:
 *   - Authorization header with Bearer token
 *   - ocrResultId in URL params
 *
 * Returns:
 *   - Full OCR result including extracted text and summary
 */
router.get("/:ocrResultId", requireAuth(), getOCRResult);

/**
 * GET /api/ocr
 * Get paginated list of user's OCR history
 * Requires:
 *   - Authorization header with Bearer token
 * Query params (optional):
 *   - page: page number (default: 1)
 *   - limit: results per page (default: 10)
 *   - sort: sort field with direction (default: "-created_at")
 *
 * Returns:
 *   - Paginated list of OCR results (without large text fields)
 *   - Pagination metadata
 */
router.get("/", requireAuth(), getUserOCRHistory);

/**
 * DELETE /api/ocr/:ocrResultId
 * Soft delete an OCR result
 * Requires:
 *   - Authorization header with Bearer token
 *   - ocrResultId in URL params
 *
 * Returns:
 *   - Success message
 */
router.delete("/:ocrResultId", requireAuth(), deleteOCRResult);

export default router;
