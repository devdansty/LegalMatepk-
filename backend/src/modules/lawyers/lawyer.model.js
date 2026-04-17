// import mongoose from "mongoose";

// const LawyerSchema = new mongoose.Schema({
//   user: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // if lawyer logs in

//   name: { type: String, required: true },
//   email: String,
//   phone: String,

//   specialization: {
//     type: [String], // multiple domains
//     enum: [
//       "family",
//       "criminal",
//       "corporate",
//       "property",
//       "cybercrime",
//       "immigration"
//     ]
//   },

//   experience_years: Number,

//   city: String,
//   province: String,
//   country: { type: String, default: "Pakistan" },

//   law_firm: String,
//   bio: String,

//   consultation_fee: Number,

//   availability: {
//     online: { type: Boolean, default: true },
//     in_person: { type: Boolean, default: true }
//   },

//   rating: { type: Number, default: 0 },
//   reviews_count: { type: Number, default: 0 },

//   verified: { type: Boolean, default: false },

//   created_at: { type: Date, default: Date.now }
// });

// export default mongoose.models.Lawyer || mongoose.model("Lawyer", LawyerSchema);

import mongoose from "mongoose";

const LawyerSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // linked account

  // Basic Info
  name: { type: String, required: true },
  email: { type: String, required: true },
  phone: { type: String, required: true },

  // Professional Details
  specialization: { 
    type: [String], // ["family", "criminal", "corporate", "property", "cybercrime", "immigration"]
    required: true
  },
  city: { type: String, required: true },
  experience_years: { type: Number, required: true },
  bio: { type: String, required: true },

  // Legal Documents
  cnic: { type: String, required: true }, // XXXXX-XXXXXXX-X format
  cnic_file: { type: Buffer, required: true }, // Stored as binary
  cnic_filename: { type: String },

  enrollment_number: { type: String, required: true },
  
  bar_council: { type: String, required: true },
  license_file: { type: Buffer, required: true }, // Stored as binary
  license_filename: { type: String },

  // Status & Verification
  status: {
    type: String,
    enum: ["pending", "approved", "rejected"],
    default: "approved"
  },
  verified: { type: Boolean, default: true }, // temporary: auto-verified until admin flow is added
  is_visible: { type: Boolean, default: true },
  
  rejection_reason: { type: String, default: null }, // If rejected

  // Timestamps
  created_at: { type: Date, default: Date.now },
  approved_at: { type: Date, default: null },
  updated_at: { type: Date, default: Date.now }
});

// Index for admin queries
LawyerSchema.index({ status: 1, created_at: -1 });

export default mongoose.models.Lawyer || mongoose.model("Lawyer", LawyerSchema);