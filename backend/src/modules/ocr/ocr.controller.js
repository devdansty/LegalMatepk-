import OCRResult from "./ocr.model.js";
import {
  callQwen2Model,
  callOCRService,
  isSupportedFileType,
  getFileTypeFromMime,
  getDefaultQuery
} from "./ocr.service.js";

/**
 * Handle OCR document summarization
 * Receives a file and optional query, extracts text via OCR service,
 * and generates summary via Qwen 2 model
 */
export const handleDocumentSummarization = async (req, res) => {
  const session = null;
  try {
    console.log("[OCR_DEBUG_HIT] POST /api/ocr received");
    console.log("[OCR_DEBUG_META]", {
      hasAuthHeader: Boolean(req.headers.authorization),
      contentType: req.headers["content-type"],
      bodyKeys: Object.keys(req.body || {}),
      hasFile: Boolean(req.file),
      fileField: req.file?.fieldname || null,
      fileName: req.file?.originalname || null,
      mimeType: req.file?.mimetype || null,
      queryPreview: (req.body?.query || "").slice(0, 120)
    });

    // Debug: Show file buffer details
    if (req.file?.buffer) {
      const buffer = req.file.buffer;
      console.log("[OCR_FILE_BUFFER]", {
        bufferSize: buffer.length,
        firstBytes: buffer.slice(0, 16).toString('hex'),
        lastBytes: buffer.slice(-16).toString('hex'),
        isPDF: buffer.slice(0, 4).toString() === '%PDF',
        isJPEG: buffer[0] === 0xFF && buffer[1] === 0xD8,
        isPNG: buffer.slice(0, 8).toString('hex') === '89504e470d0a1a0a'
      });
    }

    // Get authenticated user (or guest test user)
    const userId = req.user?._id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Unauthorized",
        details: "No user context found for OCR request"
      });
    }

    // Check if file was uploaded
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: "No file provided",
        details: "Please upload a file (.pdf, .docx, .jpg, etc.)"
      });
    }

    const { query } = req.body;
    const isDefaultQuery = !query || query.trim() === "";

    console.log(`[OCR Controller] Validating file type: ${req.file.mimetype}`);

    // Validate file type (Python OCR currently supports image files)
    if (!isSupportedFileType(req.file.mimetype)) {
      console.log(`[OCR Controller] File type validation FAILED: ${req.file.mimetype}`);
      return res.status(400).json({
        success: false,
        error: "Unsupported file type",
        details: `File type ${req.file.mimetype} is not supported. Supported types: JPG, JPEG, PNG`
      });
    }

    // Validate file size (max 25 MB)
    const MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024;
    if (req.file.size > MAX_FILE_SIZE_BYTES) {
      return res.status(400).json({
        success: false,
        error: "File too large",
        details: `Maximum file size is 25 MB. Your file is ${(req.file.size / 1024 / 1024).toFixed(2)} MB`
      });
    }

    console.log(`[OCR Controller] Processing file: ${req.file.originalname} (${req.file.size} bytes)`);
    console.log(`[OCR Controller] File validation passed.`);

    // Step 1: Call OCR Service to extract text FIRST (before saving to DB)
    console.log("[OCR Controller] Step 1: Calling OCR Service...");
    const ocrResponse = await callOCRService(
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype
    );

    if (ocrResponse.status === "failed") {
      console.error(
        `[OCR Controller] OCR extraction failed: ${ocrResponse.error}`
      );

      return res.status(500).json({
        success: false,
        error: "OCR extraction failed",
        details: ocrResponse.error,
        error_details: ocrResponse.error_details
      });
    }

    console.log(`[OCR Controller] Text extraction successful. Extracted ${ocrResponse.extracted_text.length} characters`);

    // Step 2: Check for duplicate documents (same text) to avoid redundant API calls
    console.log("[OCR Controller] Step 2: Checking for duplicate documents...");
    const duplicateOCR = await OCRResult.findOne({
      "extracted_text.raw_text": ocrResponse.extracted_text,
      "summary.summarization_status": "success"  // Only use if summary was successful
    }).select("file_info.original_filename summary extracted_text processing_metadata");

    let summaryResponse;
    let usedDuplicate = false;

    if (duplicateOCR) {
      console.log(`[OCR Controller] ✅ Found duplicate document! Filename: ${duplicateOCR.file_info.original_filename}`);
      console.log(`[OCR Controller] Reusing summary from DB instead of calling model again`);
      
      summaryResponse = {
        summarized_text: duplicateOCR.summary.summarized_text,
        status: "success",
        response_time_ms: 0,  // No API call made
        raw_response: { reused_from_duplicate: true }
      };
      usedDuplicate = true;
    } else {
      // No duplicate found, call Qwen2 model
      console.log("[OCR Controller] No duplicate found. Calling Qwen2 model for summarization...");
      summaryResponse = await callQwen2Model(
        ocrResponse.extracted_text,
        isDefaultQuery ? null : query,
        ocrResponse.language || "unknown"
      );
    }

    const finalQuery = isDefaultQuery ? getDefaultQuery() : query;
    const totalProcessingTime =
      ocrResponse.response_time_ms + (summaryResponse.response_time_ms || 0);

    // Step 3: Create OCR result document in database
    console.log(`[OCR Controller] Creating OCR result document in DB...`);
    const ocrResult = new OCRResult({
      user_id: userId,
      file_info: {
        original_filename: req.file.originalname,
        file_type: getFileTypeFromMime(req.file.mimetype),
        file_size_bytes: req.file.size,
        uploaded_at: new Date()
      },
      query: {
        user_query: query || null,
        is_default_query: isDefaultQuery
      },
      extracted_text: {
        raw_text: ocrResponse.extracted_text,
        confidence_score: ocrResponse.confidence_score,
        extraction_status: "success",
        engine_used: ocrResponse.engine_used || "paddle_ocr",
        language_detected: ocrResponse.language || "unknown",
        routing_reason: ocrResponse.routing_reason || null
      },
      summary: {
        summarized_text: summaryResponse.summarized_text,
        summarization_status:
          summaryResponse.status === "success" ? "success" : "failed",
        summarization_error:
          summaryResponse.status === "failed" ? summaryResponse.error : null,
        model_used: "qwen-2",
        generated_at:
          summaryResponse.status === "success" ? new Date() : null
      },
      processing_metadata: {
        ocr_engine: ocrResponse.engine_used || "paddle_ocr",
        ocr_routing_decision: ocrResponse.routing_reason || "standard paddle extraction",
        ocr_service_response_time_ms: ocrResponse.response_time_ms,
        summarization_service_response_time_ms:
          summaryResponse.response_time_ms || null,
        total_processing_time_ms: totalProcessingTime,
        used_duplicate_summary: usedDuplicate,  // Track if summary was from duplicate
        duplicate_source_id: usedDuplicate ? duplicateOCR._id : null  // Link to original document
      }
    });
    await ocrResult.save();

    console.log(
      `[OCR Controller] Processing complete. Saved to DB with ID: ${ocrResult._id}. Total time: ${ocrResult.processing_metadata.total_processing_time_ms}ms`
    );

    if (summaryResponse.status === "failed") {
      console.error(
        `[OCR Controller] Summarization failed: ${summaryResponse.error}`
      );

      return res.status(502).json({
        success: false,
        error: "Document summarization failed",
        details: summaryResponse.error,
        error_details: summaryResponse.error_details,
        data: {
          ocrResultId: ocrResult._id,
          extractedText: ocrResult.extracted_text.raw_text,
          query: finalQuery,
          wasDefaultQuery: isDefaultQuery,
          stage: "ocr_complete_summary_failed",
          processingTime: {
            ocr_ms: ocrResult.processing_metadata.ocr_service_response_time_ms,
            summarization_ms:
              ocrResult.processing_metadata.summarization_service_response_time_ms,
            total_ms: ocrResult.processing_metadata.total_processing_time_ms
          }
        }
      });
    }

    // Return successful response
    res.status(200).json({
      success: true,
      message: usedDuplicate 
        ? "Document processed successfully (summary reused from duplicate)"
        : "Document processed successfully",
      data: {
        ocrResultId: ocrResult._id,
        extractedText: ocrResult.summary.summarized_text,
        rawExtractedText: ocrResult.extracted_text.raw_text,
        summary: ocrResult.summary.summarized_text,
        summarizedText: ocrResult.summary.summarized_text,
        query: finalQuery,
        wasDefaultQuery: isDefaultQuery,
        usedDuplicateSummary: usedDuplicate,  // Indicate if summary was from duplicate
        duplicateSourceId: usedDuplicate ? duplicateOCR._id : null,  // Link to original
        duplicateSourceFilename: usedDuplicate ? duplicateOCR.file_info.original_filename : null,  // Show which file was duplicated
        confidenceScore: ocrResult.extracted_text.confidence_score,
        stage: "ocr_and_summary",
        processingTime: {
          ocr_ms: ocrResult.processing_metadata.ocr_service_response_time_ms,
          summarization_ms:
            ocrResult.processing_metadata.summarization_service_response_time_ms,
          total_ms: ocrResult.processing_metadata.total_processing_time_ms
        }
      }
    });

  } catch (error) {
    console.error("[OCR Controller] Unexpected error:", error);

    return res.status(500).json({
      success: false,
      error: "Internal server error",
      details: process.env.NODE_ENV === "development" ? error.message : "An unexpected error occurred"
    });
  }
};

/**
 * Get OCR result by ID
 * Used to retrieve previously processed documents
 */
export const getOCRResult = async (req, res) => {
  try {
    const { ocrResultId } = req.params;
    const userId = req.user._id;

    const ocrResult = await OCRResult.findById(ocrResultId);

    if (!ocrResult) {
      return res.status(404).json({
        success: false,
        error: "OCR result not found"
      });
    }

    // Check if user owns this result
    if (ocrResult.user_id.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        error: "Unauthorized - you don't have access to this result"
      });
    }

    res.json({
      success: true,
      data: ocrResult
    });

  } catch (error) {
    console.error("[OCR Controller] Error retrieving OCR result:", error);
    res.status(500).json({
      success: false,
      error: "Failed to retrieve OCR result",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

/**
 * Get user's OCR history
 * Returns paginated list of all OCR results for the authenticated user
 */
export const getUserOCRHistory = async (req, res) => {
  try {
    const userId = req.user._id;
    const { page = 1, limit = 10, sort = "-created_at" } = req.query;

    const skip = (page - 1) * limit;

    // Get total count
    const total = await OCRResult.countDocuments({
      user_id: userId,
      deleted_at: null
    });

    // Get paginated results
    const results = await OCRResult.find({
      user_id: userId,
      deleted_at: null
    })
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit))
      .select("-extracted_text.raw_text -summary.summarized_text") // Exclude large text fields for list view
      .exec();

    res.json({
      success: true,
      data: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit),
        results
      }
    });

  } catch (error) {
    console.error("[OCR Controller] Error retrieving OCR history:", error);
    res.status(500).json({
      success: false,
      error: "Failed to retrieve OCR history",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

/**
 * Delete OCR result (soft delete)
 */
export const deleteOCRResult = async (req, res) => {
  try {
    const { ocrResultId } = req.params;
    const userId = req.user._id;

    const ocrResult = await OCRResult.findById(ocrResultId);

    if (!ocrResult) {
      return res.status(404).json({
        success: false,
        error: "OCR result not found"
      });
    }

    // Check if user owns this result
    if (ocrResult.user_id.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        error: "Unauthorized - you don't have access to this result"
      });
    }

    // Soft delete
    ocrResult.deleted_at = new Date();
    await ocrResult.save();

    res.json({
      success: true,
      message: "OCR result deleted successfully"
    });

  } catch (error) {
    console.error("[OCR Controller] Error deleting OCR result:", error);
    res.status(500).json({
      success: false,
      error: "Failed to delete OCR result",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};
