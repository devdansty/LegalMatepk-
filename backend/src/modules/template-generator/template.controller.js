import DocumentTemplate from "./template.model.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { spawn } from "child_process";

// ── Get __dirname equivalent in ES modules ────────────────────────────────
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ── Helpers ────────────────────────────────────────────────────────────────

/**
 * Converts a title string into a URL-safe slug.
 * e.g. "Affidavit – Benami Property" → "affidavit-benami-property"
 */
const toSlug = (title) =>
  title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");

/**
 * Executes Python script to fill .docx template with values.
 * Returns promise that resolves with output file path.
 */
const executeFilledDocument = (inputFile, outputFile, fieldValues) => {
  return new Promise((resolve, reject) => {
    const pythonScript = path.join(__dirname, "fill-document.py");

    const python = spawn("python", [
      pythonScript,
      inputFile,
      outputFile,
      JSON.stringify(fieldValues),
    ]);

    let stderr = "";
    let stdout = "";

    python.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    python.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    python.on("close", (code) => {
      if (code === 0) {
        resolve(outputFile);
      } else {
        reject(new Error(`Python script failed: ${stderr}`));
      }
    });

    python.on("error", (err) => {
      reject(new Error(`Failed to spawn Python process: ${err.message}`));
    });
  });
};

/**
 * Validates that every field name referenced in templateContent
 * as {{field_name}} actually exists in the fields array.
 * Returns an array of unknown placeholder names (empty = OK).
 */
const findUnknownPlaceholders = (templateContent, fields) => {
  const declared = new Set(fields.map((f) => f.name));
  const used = [...templateContent.matchAll(/\{\{([^}]+)\}\}/g)].map(
    (m) => m[1]
  );
  return [...new Set(used)].filter((p) => !declared.has(p));
};

// ── Controllers ────────────────────────────────────────────────────────────

/**
 * GET /api/templates
 * List all active templates.
 * Query params:
 *   category  – filter by category
 *   search    – full-text search on title / description / tags
 *   page      – page number (default 1)
 *   limit     – items per page (default 20, max 100)
 */
export const listTemplates = async (req, res) => {
  try {
    const { category, search, page = 1, limit = 20 } = req.query;

    const filter = { isActive: true };

    if (category) {
      filter.category = category.toLowerCase();
    }

    if (search) {
      const re = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
      filter.$or = [
        { title: re },
        { description: re },
        { tags: re },
        { subcategory: re },
      ];
    }

    const pageNum = Math.max(1, parseInt(page, 10));
    const pageSize = Math.min(100, Math.max(1, parseInt(limit, 10)));
    const skip = (pageNum - 1) * pageSize;

    const [templates, total] = await Promise.all([
      DocumentTemplate.find(filter)
        .select("-__v")   // exclude version key only
        .sort({ category: 1, title: 1 })
        .skip(skip)
        .limit(pageSize)
        .lean(),
      DocumentTemplate.countDocuments(filter),
    ]);

    return res.json({
      success: true,
      data: templates,
      pagination: {
        total,
        page: pageNum,
        limit: pageSize,
        pages: Math.ceil(total / pageSize),
      },
    });
  } catch (err) {
    console.error("[Templates] listTemplates error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * GET /api/templates/:id
 * Return a single template including its full templateContent and fields.
 */
export const getTemplate = async (req, res) => {
  try {
    const template = await DocumentTemplate.findOne({
      _id: req.params.id,
      isActive: true,
    }).select("-__v");

    if (!template) {
      return res.status(404).json({ success: false, message: "Template not found" });
    }

    return res.json({ success: true, data: template });
  } catch (err) {
    if (err.name === "CastError") {
      return res.status(400).json({ success: false, message: "Invalid template ID" });
    }
    console.error("[Templates] getTemplate error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * GET /api/templates/slug/:slug
 * Fetch a template by its slug (useful for direct linking from the UI).
 */
export const getTemplateBySlug = async (req, res) => {
  try {
    const template = await DocumentTemplate.findOne({
      slug: req.params.slug.toLowerCase(),
      isActive: true,
    }).select("-__v");

    if (!template) {
      return res.status(404).json({ success: false, message: "Template not found" });
    }

    return res.json({ success: true, data: template });
  } catch (err) {
    console.error("[Templates] getTemplateBySlug error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * GET /api/templates/categories
 * Return the list of distinct categories that have at least one active template.
 */
export const listCategories = async (_req, res) => {
  try {
    const categories = await DocumentTemplate.distinct("category", {
      isActive: true,
    });
    return res.json({ success: true, data: categories.sort() });
  } catch (err) {
    console.error("[Templates] listCategories error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * POST /api/templates
 * Create a new template.
 * Body (JSON):
 * {
 *   title, category, subcategory?, language?, description?, tags?,
 *   fields: [{ name, label, type, placeholder?, required?, options?, order? }],
 *   templateContent,
 *   sourceFileName?, version?, isActive?
 * }
 */
export const createTemplate = async (req, res) => {
  try {
    const {
      title,
      slug,
      category,
      subcategory,
      language,
      description,
      tags,
      fields,
      templateContent,
      sourceFileName,
      version,
      isActive,
    } = req.body;

    // Basic validation
    if (!title || !category || !fields || !templateContent) {
      return res.status(400).json({
        success: false,
        message: "title, category, fields, and templateContent are required.",
      });
    }

    // Auto-generate slug if not provided
    const resolvedSlug = slug ? slug.toLowerCase().trim() : toSlug(title);

    // Warn about undeclared placeholders (non-fatal)
    const unknown = findUnknownPlaceholders(templateContent, fields);
    const warnings = unknown.length
      ? [`Undeclared placeholders in templateContent: ${unknown.join(", ")}`]
      : [];

    const template = await DocumentTemplate.create({
      title,
      slug: resolvedSlug,
      category,
      subcategory,
      language,
      description,
      tags,
      fields,
      templateContent,
      sourceFileName,
      version,
      isActive,
    });

    return res.status(201).json({ success: true, data: template, warnings });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "A template with that slug already exists.",
      });
    }
    if (err.name === "ValidationError") {
      return res.status(400).json({ success: false, message: err.message });
    }
    console.error("[Templates] createTemplate error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * PUT /api/templates/:id
 * Full update of an existing template.
 */
export const updateTemplate = async (req, res) => {
  try {
    const allowed = [
      "title", "slug", "category", "subcategory", "language",
      "description", "tags", "fields", "templateContent",
      "sourceFileName", "version", "isActive",
    ];

    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        updates[key] = req.body[key];
      }
    }

    if (updates.title && !req.body.slug) {
      updates.slug = toSlug(updates.title);
    }
    if (updates.slug) {
      updates.slug = updates.slug.toLowerCase().trim();
    }

    const template = await DocumentTemplate.findByIdAndUpdate(
      req.params.id,
      { $set: updates },
      { new: true, runValidators: true }
    ).select("-__v");

    if (!template) {
      return res.status(404).json({ success: false, message: "Template not found" });
    }

    return res.json({ success: true, data: template });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "A template with that slug already exists.",
      });
    }
    if (err.name === "CastError") {
      return res.status(400).json({ success: false, message: "Invalid template ID" });
    }
    if (err.name === "ValidationError") {
      return res.status(400).json({ success: false, message: err.message });
    }
    console.error("[Templates] updateTemplate error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * DELETE /api/templates/:id
 * Soft-delete (sets isActive = false). Hard-delete available via ?hard=true.
 */
export const deleteTemplate = async (req, res) => {
  try {
    if (req.query.hard === "true") {
      const result = await DocumentTemplate.findByIdAndDelete(req.params.id);
      if (!result) {
        return res.status(404).json({ success: false, message: "Template not found" });
      }
      return res.json({ success: true, message: "Template permanently deleted." });
    }

    const template = await DocumentTemplate.findByIdAndUpdate(
      req.params.id,
      { $set: { isActive: false } },
      { new: true }
    );

    if (!template) {
      return res.status(404).json({ success: false, message: "Template not found" });
    }

    return res.json({ success: true, message: "Template deactivated.", data: { _id: template._id } });
  } catch (err) {
    if (err.name === "CastError") {
      return res.status(400).json({ success: false, message: "Invalid template ID" });
    }
    console.error("[Templates] deleteTemplate error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * POST /api/templates/bulk
 * Insert multiple templates at once (used by the seed script).
 * Body: { templates: [ ...template objects ] }
 * Uses insertMany with ordered:false so a duplicate-slug error on one
 * document does not abort the rest.
 */
export const bulkInsertTemplates = async (req, res) => {
  try {
    const { templates } = req.body;

    if (!Array.isArray(templates) || templates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Provide a non-empty 'templates' array.",
      });
    }

    // Auto-generate slugs for any entry that omits them
    const prepared = templates.map((t) => ({
      ...t,
      slug: t.slug ? t.slug.toLowerCase().trim() : toSlug(t.title),
    }));

    const result = await DocumentTemplate.insertMany(prepared, {
      ordered: false,
    });

    return res.status(201).json({
      success: true,
      inserted: result.length,
      data: result.map((d) => ({ _id: d._id, slug: d.slug, title: d.title })),
    });
  } catch (err) {
    // Partial-success: some docs inserted, some hit duplicate key
    if (err.name === "BulkWriteError" || err.code === 11000) {
      const inserted = err.result?.nInserted ?? 0;
      return res.status(207).json({
        success: false,
        message: "Some templates were not inserted (duplicate slugs).",
        inserted,
        errors: err.writeErrors?.map((e) => e.errmsg) ?? [err.message],
      });
    }
    console.error("[Templates] bulkInsertTemplates error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * GET /api/templates/:id/download-original
 * Download the original .docx template file as-is (without filling).
 * The file is served directly from the file system.
 */
export const downloadOriginalTemplate = async (req, res) => {
  try {
    const template = await DocumentTemplate.findOne({
      _id: req.params.id,
      isActive: true,
    }).select("sourceFileName title");

    if (!template) {
      return res.status(404).json({
        success: false,
        message: "Template not found",
      });
    }

    if (!template.sourceFileName) {
      return res.status(400).json({
        success: false,
        message: "Original template file not available for this template",
      });
    }

    // Construct the file path
    const baseDir = path.join(__dirname, "../../../../docs/legal-templates/property/Placeholder-doc");
    const filePath = path.join(baseDir, template.sourceFileName);

    // Validate that the file exists and is within the allowed directory
    const normalizedPath = path.normalize(filePath);
    const normalizedBase = path.normalize(baseDir);

    if (!normalizedPath.startsWith(normalizedBase)) {
      return res.status(403).json({
        success: false,
        message: "Access denied",
      });
    }

    if (!fs.existsSync(filePath)) {
      console.error("[Templates] File not found:", filePath);
      return res.status(404).json({
        success: false,
        message: "Template file not found on server",
      });
    }

    // Set response headers and status code for file download
    res.status(200);
    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="${template.sourceFileName}"`
    );

    // Send the file
    const fileStream = fs.createReadStream(filePath);
    fileStream.pipe(res);

    fileStream.on("error", (err) => {
      console.error("[Templates] Error streaming file:", err);
      if (!res.headersSent) {
        res.status(500).json({ success: false, message: "Error downloading file" });
      }
    });
  } catch (err) {
    console.error("[Templates] downloadOriginalTemplate error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
};

/**
 * POST /api/templates/generate
 * Generate a filled document (.docx) from template with user-provided values.
 * Reads original .docx file, preserves formatting, replaces placeholders,
 * and streams filled document to client.
 * 
 * Body: {
 *   templateId: "_id or slug",
 *   fieldValues: { field_name: "value", ... }
 * }
 */
export const generateDocument = async (req, res) => {
  let outputFilePath = null;

  try {
    const { templateId, fieldValues } = req.body;

    if (!templateId || !fieldValues || typeof fieldValues !== "object") {
      return res.status(400).json({
        success: false,
        message: "Provide 'templateId' and 'fieldValues' object.",
      });
    }

    // Fetch template (support both ID and slug)
    let template = await DocumentTemplate.findOne({
      $or: [{ _id: templateId }, { slug: templateId }],
      isActive: true,
    }).select("sourceFileName slug title");

    if (!template) {
      return res.status(404).json({
        success: false,
        message: "Template not found.",
      });
    }

    if (!template.sourceFileName) {
      return res.status(400).json({
        success: false,
        message: "Original template file not available.",
      });
    }

    // Construct paths
    const templateDir = path.join(
      __dirname,
      "../../../../docs/legal-templates/property/Placeholder-doc"
    );
    const inputFile = path.join(templateDir, template.sourceFileName);

    // Validate input file exists
    if (!fs.existsSync(inputFile)) {
      console.error("[Templates] Original template file not found:", inputFile);
      return res.status(404).json({
        success: false,
        message: "Original template file not found on server.",
      });
    }

    // Create output directory for filled documents
    const outputDir = path.join(__dirname, "../../../generated-documents");
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Generate unique output filename
    const timestamp = Date.now();
    const outputFilename = `${template.slug}_${timestamp}.docx`;
    outputFilePath = path.join(outputDir, outputFilename);

    // Call Python script to fill document with formatting preserved
    await executeFilledDocument(inputFile, outputFilePath, fieldValues);

    // Verify output file was created
    if (!fs.existsSync(outputFilePath)) {
      console.error("[Templates] Failed to generate filled document");
      return res.status(500).json({
        success: false,
        message: "Failed to generate document.",
      });
    }

    // Set response headers and status code for file download
    res.status(200);
    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="${outputFilename}"`
    );

    // Stream file to client
    const fileStream = fs.createReadStream(outputFilePath);

    fileStream.on("error", (err) => {
      console.error("[Templates] Error streaming file:", err);
      if (!res.headersSent) {
        res.status(500).json({ success: false, message: "Error sending file." });
      }
    });

    // Clean up file after streaming (optional - adjust based on your needs)
    fileStream.on("end", () => {
      // Keep file on server for record-keeping
      // If you want to delete after download, uncomment:
      // fs.unlink(outputFilePath, (err) => {
      //   if (err) console.error("Error deleting temp file:", err);
      // });
    });

    fileStream.pipe(res);

    console.log(
      `[Templates] Generated filled document: ${outputFilename} for template: ${template.slug}`
    );
  } catch (err) {
    console.error("[Templates] generateDocument error:", err);

    // Clean up on error
    if (outputFilePath && fs.existsSync(outputFilePath)) {
      fs.unlinkSync(outputFilePath);
    }

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to generate document.",
    });
  }
};
