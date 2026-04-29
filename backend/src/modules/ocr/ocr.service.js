import axios from "axios";
import FormData from "form-data";

/**
 * TODO: Update these endpoints with actual service URLs once they are deployed
 * Current placeholders are for development/testing
 */

// Python OCR service endpoint
const PYTHON_OCR_SERVICE_URL =
  process.env.PYTHON_OCR_SERVICE_URL ||
  process.env.PYTHON_API_URL ||
  "http://localhost:8000";
const OCR_EXTRACT_ENDPOINT = `${PYTHON_OCR_SERVICE_URL}/ocr/extract`;

const QWEN2_MODEL_URL =
  process.env.QWEN2_MODEL_URL ||
  process.env.PYTHON_API_URL ||
  "http://localhost:8000";
const QWEN2_SUMMARIZE_ENDPOINT = `${QWEN2_MODEL_URL}/api/summarize`;

// Default summarizer query if user doesn't provide one
const DEFAULT_SUMMARIZER_QUERY = "Please summarize and clearly explain the key points and important information from the attached document in a concise and professional manner.";
const BROKEN_URDU_REPAIR_PROMPT = "The following Urdu text is broken into individual characters or fragments due to OCR errors. Please reassemble the characters into meaningful words and sentences, maintaining the original meaning. Do not add or remove information.";

/**
 * Detect whether OCR text appears to be broken Urdu fragments (single chars / tiny tokens).
 * Heuristic-based by design to avoid expensive language processing.
 * @param {string} text
 * @returns {boolean}
 */
const isBrokenUrduText = (text) => {
  if (!text || typeof text !== "string") return false;

  // Urdu Unicode block + Arabic presentation forms commonly seen in OCR output
  const urduRegex = /[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/;
  if (!urduRegex.test(text)) return false;

  const tokens = text
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(Boolean);

  if (tokens.length < 8) return false;

  const urduTokens = tokens.filter((t) => urduRegex.test(t));
  if (urduTokens.length < 5) return false;

  const singleCharUrduTokens = urduTokens.filter((t) => {
    const chars = [...t];
    return chars.length === 1;
  }).length;

  const tinyUrduTokens = urduTokens.filter((t) => {
    const chars = [...t];
    return chars.length <= 2;
  }).length;

  const singleCharRatio = singleCharUrduTokens / urduTokens.length;
  const tinyTokenRatio = tinyUrduTokens / urduTokens.length;

  // OCR-broken Urdu usually has many 1-char/2-char fragments
  return singleCharRatio >= 0.45 || tinyTokenRatio >= 0.7;
};

/**
 * Build the final prompt sent to the summarization model.
 * Adds repair instruction only when Urdu OCR text looks fragmented.
 * @param {string} extractedText
 * @param {string|null} userQuery
 * @param {string} detectedLanguage
 * @returns {{query: string, appliedRepairPrompt: boolean}}
 */
const buildSummarizationQuery = (extractedText, userQuery = null, detectedLanguage = "unknown") => {
  const baseQuery = userQuery || DEFAULT_SUMMARIZER_QUERY;
  const normalizedLang = String(detectedLanguage || "unknown").toLowerCase();
  const isUrduOrMixed = normalizedLang === "urdu" || normalizedLang === "mixed";
  const shouldApplyRepairPrompt = isUrduOrMixed && isBrokenUrduText(extractedText);

  if (!shouldApplyRepairPrompt) {
    return {
      query: baseQuery,
      appliedRepairPrompt: false
    };
  }

  return {
    query: `${BROKEN_URDU_REPAIR_PROMPT}\n\nThen, ${baseQuery}`,
    appliedRepairPrompt: true
  };
};

/**
 * Call Python OCR Service to extract text from uploaded file
 * @param {Buffer} fileBuffer - The file content as a buffer
 * @param {string} filename - Original filename
 * @param {string} mimeType - File MIME type
 * @returns {Promise<Object>} - Extracted text and metadata
 */
export const callOCRService = async (fileBuffer, filename, mimeType) => {
  try {
    const startTime = Date.now();

    console.log(`[OCR Service] Calling OCR service for file: ${filename}`);
    console.log(`[OCR Service] Target URL: ${OCR_EXTRACT_ENDPOINT}`);
    console.log(`[OCR Service] File size: ${fileBuffer.length} bytes, MIME: ${mimeType}`);

    const form = new FormData();
    
    // Determine correct MIME type from filename if it's octet-stream
    let correctMimeType = mimeType;
    if (mimeType === "application/octet-stream") {
      const ext = filename.toLowerCase().match(/\.[^.]*$/)?.[0];
      const mimeMap = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif"
      };
      correctMimeType = mimeMap[ext] || "image/jpeg";
      console.log(`[OCR Service] Corrected MIME type from extension: ${ext} -> ${correctMimeType}`);
    }
    
    form.append("file", fileBuffer, {
      filename,
      contentType: correctMimeType
    });

    const response = await axios.post(
      OCR_EXTRACT_ENDPOINT,
      form,
      {
        headers: {
          ...form.getHeaders()
        },
        timeout: 30000 // 30 second timeout for OCR processing
      }
    );

    const responseTime = Date.now() - startTime;

    console.log(`[OCR Service] Successfully extracted text in ${responseTime}ms using ${response.data.engine_used || 'paddle_ocr'}`);

    return {
      extracted_text: response.data.raw_text || response.data.text || response.data.extracted_text || "",
      confidence_score: response.data.confidence || null,
      engine_used: response.data.engine_used || "paddle_ocr",
      language: response.data.language || "unknown",
      routing_reason: response.data.routing_reason || null,
      status: "success",
      response_time_ms: responseTime,
      raw_response: response.data
    };
  } catch (error) {
    console.error("[OCR Service] Error calling OCR service:", error.message);

    return {
      extracted_text: null,
      status: "failed",
      error: error.message,
      error_details: {
        code: error.code,
        status: error.response?.status,
        message: error.response?.data?.message || error.message
      }
    };
  }
};

/**
 * Call Qwen 2 Model Service to summarize extracted text
 * @param {string} extractedText - The text extracted from OCR
 * @param {string} userQuery - User's custom query (or null for default)
 * @param {string} detectedLanguage - OCR detected language/script (english/urdu/mixed/unknown)
 * @returns {Promise<Object>} - Summarized text and metadata
 */
export const callQwen2Model = async (extractedText, userQuery = null, detectedLanguage = "unknown") => {
  try {
    const startTime = Date.now();
    const { query, appliedRepairPrompt } = buildSummarizationQuery(
      extractedText,
      userQuery,
      detectedLanguage
    );

    console.log(`[Qwen2 Model] Calling Qwen 2 model with:`);
    console.log(`[Qwen2 Model]   - Text length: ${extractedText?.length || 0} chars`);
    console.log(`[Qwen2 Model]   - OCR language: ${detectedLanguage}`);
    console.log(`[Qwen2 Model]   - Repair prompt applied: ${appliedRepairPrompt}`);
    console.log(`[Qwen2 Model]   - Query length: ${query.length} chars`);
    console.log(`[Qwen2 Model]   - Endpoint: ${QWEN2_SUMMARIZE_ENDPOINT}`);

    // Call the Qwen2 streaming API with responseType: 'stream' to properly handle streaming
    const response = await axios.post(
      QWEN2_SUMMARIZE_ENDPOINT,
      {
        text: extractedText,
        query: query,
        session_id: "ocr-session"
      },
      {
        headers: {
          "Content-Type": "application/json"
        },
        timeout: 120000, // 120 second timeout for model inference
        responseType: 'stream'  // Handle as stream like chatbot does
      }
    );

    // Collect streaming text chunks into complete response
    const summarizedText = await new Promise((resolve, reject) => {
      let fullResponse = '';
      
      response.data.on('data', (chunk) => {
        fullResponse += chunk.toString();
        // console.log(`[Qwen2 Model] Received chunk: ${chunk.toString().substring(0, 50)}...`);
      });
      
      response.data.on('end', () => {
        const responseTime = Date.now() - startTime;
        console.log(`[Qwen2 Model] Stream complete. Total text: ${fullResponse.length} chars`);
        console.log(`[Qwen2 Model] Generated summary in ${responseTime}ms`);
        
        if (!fullResponse || fullResponse.trim().length === 0) {
          console.warn(`[Qwen2 Model] ⚠️  Empty response received from model!`);
          resolve("");
        } else {
          resolve(fullResponse.trim());
        }
      });
      
      response.data.on('error', (error) => {
        console.error(`[Qwen2 Model] Stream error: ${error.message}`);
        reject(error);
      });
    });

    const responseTime = Date.now() - startTime;

    return {
      summarized_text: summarizedText,
      status: "success",
      applied_repair_prompt: appliedRepairPrompt,
      response_time_ms: responseTime,
      raw_response: summarizedText
    };
  } catch (error) {
    console.error("[Qwen2 Model] Error calling Qwen 2 model:", error.message);
    console.error("[Qwen2 Model] Error code:", error.code);
    console.error("[Qwen2 Model] Error status:", error.response?.status);

    return {
      summarized_text: null,
      status: "failed",
      error: error.message,
      error_details: {
        code: error.code,
        status: error.response?.status,
        message: error.response?.data?.message || error.message
      }
    };
  }
};

/**
 * Find existing OCR result with matching raw text (deduplication)
 * Checks if the exact same document has been processed before
 * @param {string} rawText - The extracted text to search for
 * @param {string} userId - User ID to search within (optional, searches all if not provided)
 * @returns {Promise<Object>} - Existing OCR result if found, null otherwise
 */
export const findDuplicateOCRByText = async (rawText, userId = null) => {
  try {
    // Note: This function will be called from controller with imported OCRResult model
    // We'll return null here and implement in controller where we have access to the model
    console.log(`[OCR Service] Checking for duplicate OCR text (${rawText.length} chars)`);
    return null;
  } catch (error) {
    console.error("[OCR Service] Error checking for duplicates:", error.message);
    return null;
  }
};

/**
 * Get the default summarizer query
 * @returns {string} - Default query
 */
export const getDefaultQuery = () => DEFAULT_SUMMARIZER_QUERY;

/**
 * Validate if file type is supported
 * @param {string} mimeType - File MIME type
 * @returns {boolean} - True if supported
 */
export const isSupportedFileType = (mimeType) => {
  const supported = [
    "image/jpeg",
    "image/jpg",
    "image/png",
    "application/pdf",
    "application/octet-stream" // Accept generic type (extension validated by multer)
  ];
  return supported.includes(mimeType);
};

/**
 * Get file type from MIME type
 * @param {string} mimeType - File MIME type
 * @returns {string} - Simplified file type
 */
export const getFileTypeFromMime = (mimeType) => {
  const typeMap = {
    "application/pdf": "pdf",
    "application/msword": "docx",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "application/octet-stream": "jpg" // Default to jpg for generic binary
  };
  return typeMap[mimeType] || "jpg"; // Default to jpg instead of unknown
};
