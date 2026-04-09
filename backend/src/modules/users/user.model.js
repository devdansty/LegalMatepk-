import mongoose from "mongoose";
const { Schema } = mongoose;

const ProfileSchema = new Schema({
  display_name: { type: String },
  bio: { type: String, default: "" },
  gender: { type: String, enum: ["male", "female", "other", null], default: null },
  dob: { type: Date, default: null },
  address: {
    city: String,
    province: String,
    country: String
  },
  avatar_url: { type: String, default: null }
}, { _id: false });

const ConsentSchema = new Schema({
  tos_accepted: { type: Boolean, default: false },
  tos_accepted_at: { type: Date, default: null },
  privacy_policy_version: { type: String, default: null }
}, { _id: false });

const UserSchema = new Schema({
  email: { type: String, required: true, unique: true, lowercase: true, index: true },
  email_verified: { type: Boolean, default: false },
  phone: { type: String, default: null, index: true, sparse: true },
  phone_verified: { type: Boolean, default: false },
  username: { type: String, unique: true, sparse: true },
  password_hash: { type: String, required: true },

  auth_providers: [{
    provider: String,
    provider_id: String,
    linked_at: Date
  }],

  preferred_language: { type: String, enum: ["ur", "roman_ur", "en"], default: "ur" },
  languages: { type: [String], default: ["ur", "roman_ur", "en"] },

  role: {
  type: String,
  enum: ["citizen", "lawyer", "admin", "guest"],
  default: "citizen"
},

  is_guest: { type: Boolean, default: false, index: true },

  profile: { type: ProfileSchema, default: {} },

  settings: {
    share_with_lawyer: { type: Boolean, default: false },
    notifications: {
      email: { type: Boolean, default: true },
      push: { type: Boolean, default: true }
    },
    data_retention_days: { type: Number, default: 365 }
  },

  created_at: { type: Date, default: () => new Date() },
  last_login_at: { type: Date, default: null },
  status: { type: String, enum: ["active", "suspended", "deleted"], default: "active" },

  consent: { type: ConsentSchema, default: {} },

  password_reset: {
    token: { type: String, default: null },
    expires_at: { type: Date, default: null }
  },

  email_verify_token: { type: String, default: null },
  email_verify_expires_at: { type: Date, default: null },

  schema_version: { type: String, default: "1.0" }
});

// indexes
UserSchema.index({ email: 1 });

// prevent overwrite error
export default mongoose.models.User || mongoose.model("User", UserSchema);