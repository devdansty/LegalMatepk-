import mongoose from "mongoose";

const ConnectionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  lawyer: { type: mongoose.Schema.Types.ObjectId, ref: "Lawyer" },

  query: String, // user's legal question

  status: {
    type: String,
    enum: ["pending", "accepted", "rejected"],
    default: "pending"
  },

  created_at: { type: Date, default: Date.now }
});

export default mongoose.models.Connection || mongoose.model("Connection", ConnectionSchema);