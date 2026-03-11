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

// PLACEHOLDER: Update this to actual Qwen 2 model service endpoint
const QWEN2_MODEL_URL = process.env.QWEN2_MODEL_URL || "http://localhost:8000";
const QWEN2_SUMMARIZE_ENDPOINT = `${QWEN2_MODEL_URL}/api/summarize`;

// Default summarizer query if user doesn't provide one
const DEFAULT_SUMMARIZER_QUERY = "Please summarize and clearly explain the key points and important information from the attached document in a concise and professional manner.";

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

    console.log(`[OCR Service] Successfully extracted text in ${responseTime}ms`);

    return {
      extracted_text: response.data.raw_text || response.data.text || response.data.extracted_text || "",
      confidence_score: response.data.confidence || null,
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
 * @returns {Promise<Object>} - Summarized text and metadata
 */
export const callQwen2Model = async (extractedText, userQuery = null) => {
  try {
    const startTime = Date.now();
    const query = userQuery || DEFAULT_SUMMARIZER_QUERY;

    console.log(`[Qwen2 Model] Calling Qwen 2 model with query length: ${query.length}`);

    // PLACEHOLDER: This assumes the Qwen 2 service accepts JSON with text and query
    // Adjust the request format based on your actual model service implementation
    const response = await axios.post(
      QWEN2_SUMMARIZE_ENDPOINT,
      {
        text: extractedText,
        query: query,
        model: "qwen-2",
        language: "en" // Can be extended to support multiple languages
      },
      {
        headers: {
          "Content-Type": "application/json"
        },
        timeout: 60000 // 60 second timeout for model inference
      }
    );

    const responseTime = Date.now() - startTime;

    console.log(`[Qwen2 Model] Successfully generated summary in ${responseTime}ms`);

    return {
      summarized_text: response.data.summary || response.data.result || "",
      status: "success",
      response_time_ms: responseTime,
      raw_response: response.data
    };
  } catch (error) {
    console.error("[Qwen2 Model] Error calling Qwen 2 model:", error.message);

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
