import express from "express";
import {
  listTemplates,
  getTemplate,
  getTemplateBySlug,
  listCategories,
  createTemplate,
  updateTemplate,
  deleteTemplate,
  bulkInsertTemplates,
  generateDocument,
  downloadOriginalTemplate,
} from "./template.controller.js";

const router = express.Router();

// ── Read-only (public) ─────────────────────────────────────────────────────

/**
 * GET /api/templates/categories
 * Returns distinct categories that have at least one active template.
 * Must be declared BEFORE /:id to avoid "categories" being treated as an ID.
 */
router.get("/categories", listCategories);

/**
 * GET /api/templates/slug/:slug
 * Fetch a single template by its slug.
 */
router.get("/slug/:slug", getTemplateBySlug);

/**
 * GET /api/templates/:id/download-original
 * Download the original .docx template file (without filling).
 * Must be declared BEFORE /:id route to match specific path first.
 */
router.get("/:id/download-original", downloadOriginalTemplate);

/**
 * GET /api/templates
 * List templates.  Supports ?category=&search=&page=&limit=
 */
router.get("/", listTemplates);

/**
 * GET /api/templates/:id
 * Fetch a single template by MongoDB ObjectId.
 */
router.get("/:id", getTemplate);

// ── Document Generation ────────────────────────────────────────────────────

/**
 * POST /api/templates/generate
 * Generate a filled .docx document from template with user values.
 * Body: { templateId: "...", fieldValues: { field: "value", ... } }
 * Returns: .docx file stream for download
 */
router.post("/generate", generateDocument);

// ── Write (admin / seed operations) ───────────────────────────────────────
// TODO: protect with requireAuth() middleware once an admin role is added.

/**
 * POST /api/templates/bulk
 * Bulk-insert templates (used by the seed script and the admin UI).
 * Must be declared BEFORE POST / to avoid route ambiguity.
 */
router.post("/bulk", bulkInsertTemplates);

/**
 * POST /api/templates
 * Create a single template.
 */
router.post("/", createTemplate);

/**
 * PUT /api/templates/:id
 * Update an existing template.
 */
router.put("/:id", updateTemplate);

/**
 * DELETE /api/templates/:id
 * Soft-delete by default.  Add ?hard=true for permanent removal.
 */
router.delete("/:id", deleteTemplate);

export default router;
