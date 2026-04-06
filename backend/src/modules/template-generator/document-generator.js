import { Document, Packer, Paragraph, TextRun } from "docx";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Generates a Word document from template content with filled values.
 * 
 * @param {string} templateContent - Template content with {{placeholder}} markers
 * @param {Object} fieldValues - Map of field names to their values
 * @param {string} documentTitle - Title for the document
 * @returns {Promise<string>} - Path to generated document
 */
export const generateDocumentFromTemplate = async (
  templateContent,
  fieldValues,
  documentTitle = "Generated Document"
) => {
  try {
    // Replace all {{placeholder}} with actual values
    let filledContent = templateContent;
    
    Object.entries(fieldValues).forEach(([key, value]) => {
      const placeholder = `{{${key}}}`;
      filledContent = filledContent.replaceAll(placeholder, String(value || ""));
    });

    // Split content into paragraphs and create document
    const paragraphs = filledContent.split("\n").map((line) => {
      return new Paragraph({
        text: line.trim() || " ", // Keep empty lines as spaces
        spacing: {
          line: 240, // 1.5 line spacing
          after: 100,
        },
      });
    });

    // Create Word document
    const doc = new Document({
      sections: [
        {
          properties: {
            page: {
              margin: {
                top: 1000,    // 1 inch (1440 twips)
                right: 1000,
                bottom: 1000,
                left: 1000,
              },
            },
          },
          children: paragraphs,
        },
      ],
    });

    // Create output directory if it doesn't exist
    const outputDir = path.join(__dirname, "../../../generated-documents");
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Generate filename with timestamp
    const timestamp = Date.now();
    const filename = `${documentTitle.replace(/\s+/g, "_")}_${timestamp}.docx`;
    const filepath = path.join(outputDir, filename);

    // Write document to file
    const bytes = await Packer.toBuffer(doc);
    fs.writeFileSync(filepath, bytes);

    console.log(`[DocumentGenerator] Document generated: ${filepath}`);
    return filepath;
  } catch (error) {
    console.error("[DocumentGenerator] Error generating document:", error);
    throw new Error(`Failed to generate document: ${error.message}`);
  }
};

/**
 * Generates a document and returns it as a buffer (for streaming).
 * Useful for immediate download without saving to disk.
 * 
 * @param {string} templateContent - Template content with {{placeholder}} markers
 * @param {Object} fieldValues - Map of field names to their values
 * @returns {Promise<Buffer>} - Document buffer ready to send as response
 */
export const generateDocumentBuffer = async (
  templateContent,
  fieldValues
) => {
  try {
    // Replace all {{placeholder}} with actual values
    let filledContent = templateContent;
    
    Object.entries(fieldValues).forEach(([key, value]) => {
      const placeholder = `{{${key}}}`;
      filledContent = filledContent.replaceAll(placeholder, String(value || ""));
    });

    // Split content into paragraphs
    const paragraphs = filledContent.split("\n").map((line) => {
      return new Paragraph({
        text: line.trim() || " ",
        spacing: {
          line: 240,
          after: 100,
        },
      });
    });

    // Create Word document
    const doc = new Document({
      sections: [
        {
          properties: {
            page: {
              margin: {
                top: 1000,
                right: 1000,
                bottom: 1000,
                left: 1000,
              },
            },
          },
          children: paragraphs,
        },
      ],
    });

    // Generate and return buffer
    const bytes = await Packer.toBuffer(doc);
    console.log("[DocumentGenerator] Document buffer generated");
    return bytes;
  } catch (error) {
    console.error("[DocumentGenerator] Error generating buffer:", error);
    throw new Error(`Failed to generate document: ${error.message}`);
  }
};

/**
 * Cleans up old generated documents (older than specified hours).
 * Run periodically as a cleanup task.
 * 
 * @param {number} hoursOld - Delete files older than this many hours
 */
export const cleanupOldDocuments = async (hoursOld = 24) => {
  try {
    const outputDir = path.join(__dirname, "../../../generated-documents");
    
    if (!fs.existsSync(outputDir)) {
      return;
    }

    const files = fs.readdirSync(outputDir);
    const now = Date.now();
    const ageInMs = hoursOld * 60 * 60 * 1000;

    let deletedCount = 0;

    files.forEach((file) => {
      const filepath = path.join(outputDir, file);
      const stat = fs.statSync(filepath);
      const fileAgeMs = now - stat.mtimeMs;

      if (fileAgeMs > ageInMs) {
        fs.unlinkSync(filepath);
        deletedCount++;
      }
    });

    if (deletedCount > 0) {
      console.log(`[DocumentGenerator] Cleaned up ${deletedCount} old documents`);
    }
  } catch (error) {
    console.error("[DocumentGenerator] Cleanup error:", error);
  }
};
