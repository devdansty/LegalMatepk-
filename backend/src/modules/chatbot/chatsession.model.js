import mongoose from "mongoose";

const ChatSessionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
    index: true,
  },

  title: {
    type: String,
    default: "New Chat",
    trim: true,
    maxlength: 120,
  },

  is_guest: { type: Boolean, default: false, index: true },

  message_count: { type: Number, default: 0 },

  last_message_at: { type: Date, default: Date.now, index: true },

  created_at: { type: Date, default: Date.now, index: true },
  updated_at: { type: Date, default: Date.now, index: true },
});

ChatSessionSchema.index({ user: 1, updated_at: -1 });
ChatSessionSchema.index({ user: 1, last_message_at: -1 });

export default mongoose.models.ChatSession ||
  mongoose.model("ChatSession", ChatSessionSchema);