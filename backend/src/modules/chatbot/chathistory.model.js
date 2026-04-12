import mongoose from "mongoose";

const ChatHistorySchema = new mongoose.Schema({
  user: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true,
    index: true 
  },
  
  message: {
    text: String,
    language: { type: String, enum: ["ur", "roman_ur", "en"], default: "ur" }
  },
  
  response: {
    text: String,
    language: { type: String, enum: ["ur", "roman_ur", "en"], default: "ur" }
  },
  
  original_language: { type: String, enum: ["ur", "roman_ur", "en"], default: "ur" },
  
  session_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "Session",
    index: true 
  },
  
  is_guest: { type: Boolean, default: false },
  
  processing_time_ms: { type: Number, default: 0 },
  
  created_at: { type: Date, default: Date.now, index: true }
});

// Index for faster user history retrieval
ChatHistorySchema.index({ user: 1, created_at: -1 });
ChatHistorySchema.index({ user: 1, is_guest: 1 });

export default mongoose.models.ChatHistory || mongoose.model("ChatHistory", ChatHistorySchema);
