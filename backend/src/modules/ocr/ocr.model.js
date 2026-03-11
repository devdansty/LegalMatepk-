import mongoose from "mongoose";
const { Schema } = mongoose;

const OCRResultSchema = new Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
    index: true
  },

  // Original file information
  file_info: {
    original_filename: { type: String, required: true },
    file_type: { type: String, enum: ["pdf", "docx", "jpg", "jpeg", "png"], required: true },
    file_size_bytes: { type: Number, required: true },
    uploaded_at: { type: Date, default: Date.now }
  },

  // Extracted text from OCR
  extracted_text: {
    raw_text: { type: String, default: null }, // Not required initially, filled after OCR
    confidence_score: { type: Number, default: null }, // Can come from Python OCR service
    extraction_status: {
      type: String,
      enum: ["pending", "success", "failed"],
      default: "pending"
    },
    extraction_error: { type: String, default: null }
  },

  // User query and summarization
  query: {
    user_query: { type: String, default: null },
    is_default_query: { type: Boolean, default: true } // true if using default summarizer query
  },

  // Summary result from Qwen 2 model
  summary: {
    summarized_text: { type: String, default: null },
    summarization_status: {
      type: String,
      enum: ["pending", "success", "failed"],
      default: "pending"
    },
    summarization_error: { type: String, default: null },
    model_used: { type: String, default: "qwen-2" },
    generated_at: { type: Date, default: null }
  },

  // Metadata
  processing_metadata: {
    ocr_service_response_time_ms: { type: Number, default: null },
    summarization_service_response_time_ms: { type: Number, default: null },
    total_processing_time_ms: { type: Number, default: null }
  },

  created_at: { type: Date, default: Date.now, index: true },
  updated_at: { type: Date, default: Date.now },
  deleted_at: { type: Date, default: null } // Soft delete support
});

// Index for user's OCR results
OCRResultSchema.index({ user_id: 1, created_at: -1 });

export default mongoose.model("OCRResult", OCRResultSchema);
