import mongoose from "mongoose";

const ConnectionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  lawyer: { type: mongoose.Schema.Types.ObjectId, ref: "Lawyer" },

  query: { type: String, required: true, trim: true }, // user's legal question

  status: {
    type: String,
    enum: ["pending", "accepted", "rejected"],
    default: "pending"
  },

  created_at: { type: Date, default: Date.now }
});

ConnectionSchema.index({ lawyer: 1, status: 1, created_at: -1 });
ConnectionSchema.index({ user: 1, created_at: -1 });

export default mongoose.models.Connection || mongoose.model("Connection", ConnectionSchema);