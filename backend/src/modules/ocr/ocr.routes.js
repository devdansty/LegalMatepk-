import express from "express";
import multer from "multer";
import { requireAuth } from "../../shared/middleware/auth.js";
import {
  handleDocumentSummarization,
  getOCRResult,
  getUserOCRHistory,
  deleteOCRResult
} from "./ocr.controller.js";

const router = express.Router();
const OCR_ALLOW_GUEST_TEST = process.env.OCR_ALLOW_GUEST_TEST === "true";
const OCR_TEST_USER_ID = process.env.OCR_TEST_USER_ID || "000000000000000000000001";

console.log("[OCR_ROUTES_INIT] OCR_ALLOW_GUEST_TEST env value:", process.env.OCR_ALLOW_GUEST_TEST);
console.log("[OCR_ROUTES_INIT] OCR_ALLOW_GUEST_TEST boolean:", OCR_ALLOW_GUEST_TEST);
console.log("[OCR_ROUTES_INIT] OCR_TEST_USER_ID:", OCR_TEST_USER_ID);

const ocrAuthOrGuest = (req, res, next) => {
  console.log("[OCR_AUTH_MIDDLEWARE] Guest test enabled:", OCR_ALLOW_GUEST_TEST);
  console.log("[OCR_AUTH_MIDDLEWARE] Has Authorization header:", !!req.headers.authorization);
  
  if (OCR_ALLOW_GUEST_TEST) {
    console.log("[OCR_AUTH_MIDDLEWARE] Bypassing auth - setting test user");
    req.user = {
      _id: OCR_TEST_USER_ID,
      role: "citizen",
      is_guest_test: true
    };
    return next();
  }
  console.log("[OCR_AUTH_MIDDLEWARE] Guest test disabled - requiring auth");
  return requireAuth()(req, res, next);
};

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
 *   - Authorization header with Bearer token
 *   - File upload (multipart/form-data) with field name "document"
 *   - Optional: "query" field in the request body for custom summarization query
 *
 * Returns:
 *   - Extracted text from the document
 *   - Generated summary
 *   - Processing metadata (response times)
 */
router.post("/", ocrAuthOrGuest, upload.single("document"), handleDocumentSummarization);

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
