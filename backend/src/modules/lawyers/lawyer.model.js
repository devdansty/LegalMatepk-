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

  name: { type: String, required: true },
  email: String,
  phone: String,

  specialization: [String], // ["family", "criminal"]

  city: String,
  experience_years: Number,

  bio: String,

  verified: { type: Boolean, default: false },

  created_at: { type: Date, default: Date.now }
});

export default mongoose.models.Lawyer || mongoose.model("Lawyer", LawyerSchema);