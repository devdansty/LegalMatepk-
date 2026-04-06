import mongoose from "mongoose";

/**
 * Schema for a single form field inside a template.
 * When the UI renders a "fill form" page, it iterates over these
 * to build the input controls dynamically.
 */
const FieldSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      // e.g. "buyer_name" — used as the {{buyer_name}} placeholder in templateContent
    },
    label: {
      type: String,
      required: true,
      trim: true,
      // Human-readable label shown in the UI, e.g. "Buyer's Full Name"
    },
    type: {
      type: String,
      required: true,
      enum: ["text", "textarea", "date", "number", "select", "email", "phone"],
      default: "text",
    },
    placeholder: {
      type: String,
      default: "",
    },
    required: {
      type: Boolean,
      default: true,
    },
    // Used only when type === "select"
    options: {
      type: [String],
      default: [],
    },
    // Display order in the form
    order: {
      type: Number,
      default: 0,
    },
  },
  { _id: false }
);

/**
 * Main DocumentTemplate schema.
 *
 * All templates are stored in a single "documenttemplates" collection.
 * The `templateContent` field holds the full text of the legal document
 * with {{field_name}} placeholders that are replaced at generation time.
 */
const DocumentTemplateSchema = new mongoose.Schema(
  {
    // ── Identity ──────────────────────────────────────────────────────────
    title: {
      type: String,
      required: true,
      trim: true,
      // e.g. "Affidavit – Benami Property"
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      // URL-safe key, e.g. "affidavit-benami-property"
      // Auto-generated from title in the controller if not provided
    },

    // ── Classification ────────────────────────────────────────────────────
    category: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
      enum: [
        "property",
        "family",
        "general",
        "criminal",
        "corporate",
        "nadra",
        "court_application",
        "other",
      ],
    },
    subcategory: {
      type: String,
      default: "",
      trim: true,
      // Optional finer classification, e.g. "sale_deed", "affidavit", "rent_agreement"
    },
    language: {
      type: String,
      enum: ["english", "urdu", "bilingual"],
      default: "english",
    },

    // ── Display ───────────────────────────────────────────────────────────
    description: {
      type: String,
      default: "",
      trim: true,
    },
    tags: {
      type: [String],
      default: [],
      // e.g. ["affidavit", "property", "benami"]
    },

    // ── Form fields ───────────────────────────────────────────────────────
    fields: {
      type: [FieldSchema],
      required: true,
      validate: {
        validator: (arr) => arr.length > 0,
        message: "A template must have at least one field.",
      },
    },

    // ── Template body ─────────────────────────────────────────────────────
    templateContent: {
      type: String,
      required: true,
      // Full legal text.  Placeholders are written as {{field_name}}.
      // Example:  "I, {{declarant_name}}, son of {{father_name}}, ..."
    },

    // ── Metadata ──────────────────────────────────────────────────────────
    sourceFileName: {
      type: String,
      default: "",
      // Original .docx / .inp filename for traceability
    },
    version: {
      type: Number,
      default: 1,
    },
    isActive: {
      type: Boolean,
      default: true,
      // Soft-delete / disable without removing from DB
    },
  },
  {
    timestamps: true,          // adds createdAt & updatedAt automatically
    collection: "documenttemplates",
  }
);

// ── Indexes ────────────────────────────────────────────────────────────────
DocumentTemplateSchema.index({ category: 1, isActive: 1 });
DocumentTemplateSchema.index({ tags: 1 });

export default mongoose.models.DocumentTemplate ||
  mongoose.model("DocumentTemplate", DocumentTemplateSchema);
