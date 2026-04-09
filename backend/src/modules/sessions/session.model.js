import mongoose from "mongoose";

const SessionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  refreshTokenHash: { type: String, required: true }, // store hashed refresh token
  userAgent: { type: String, default: null },
  ip: { type: String, default: null },
  createdAt: { type: Date, default: Date.now },
  expiresAt: { type: Date, required: true },
  revoked: { type: Boolean, default: false },
  
  // Guest session tracking
  guest_api_calls: { type: Number, default: 0 },
  guest_call_limit: { type: Number, default: 5 } // 4-5 calls for guests
});

SessionSchema.index({ user: 1 });
SessionSchema.index({ createdAt: 1 }); // for TTL queries

export default mongoose.model("Session", SessionSchema);
