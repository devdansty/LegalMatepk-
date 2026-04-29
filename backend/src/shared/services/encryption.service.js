import crypto from 'crypto';

/**
 * Database Field Encryption Service
 * 
 * Encrypts sensitive fields (CNIC, phone numbers) at rest in MongoDB
 * Uses AES-256-GCM for authenticated encryption
 * 
 * Environment Setup:
 * - ENCRYPTION_KEY: 32-byte hex string (stored securely in .env)
 *   Generate with: node -e "console.log(crypto.randomBytes(32).toString('hex'))"
 * 
 * - ENCRYPTION_IV: Optional initialization vector (auto-generated per field if not provided)
 */

const ALGORITHM = 'aes-256-gcm';
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;

// Validate encryption key is set
if (!ENCRYPTION_KEY || ENCRYPTION_KEY.length !== 64) {
  console.warn('[ENCRYPTION] Warning: ENCRYPTION_KEY not properly configured. Database encryption will be DISABLED.');
  console.warn('[ENCRYPTION] Generate a key with: node -e "console.log(crypto.randomBytes(32).toString(\'hex\'))"');
}

/**
 * Encrypts a string value
 * @param {string} plaintext - Value to encrypt
 * @returns {string} Encrypted value in format: iv:encryptedData:authTag (base64 encoded)
 */
export const encryptField = (plaintext) => {
  if (!plaintext || !ENCRYPTION_KEY) return plaintext;
  
  try {
    const key = Buffer.from(ENCRYPTION_KEY, 'hex');
    const iv = crypto.randomBytes(16); // Generate random IV
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    // Store as: base64(iv:encrypted:authTag) for easy storage and retrieval
    const combined = `${iv.toString('hex')}:${encrypted}:${authTag.toString('hex')}`;
    return Buffer.from(combined).toString('base64');
  } catch (err) {
    console.error('[ENCRYPTION_ERROR]', err.message);
    return plaintext; // Fallback: return plaintext if encryption fails
  }
};

/**
 * Decrypts an encrypted string value
 * @param {string} encrypted - Encrypted value in format: iv:encryptedData:authTag (base64 encoded)
 * @returns {string} Decrypted plaintext value
 */
export const decryptField = (encrypted) => {
  if (!encrypted || !ENCRYPTION_KEY) return encrypted;
  
  try {
    const combined = Buffer.from(encrypted, 'base64').toString('hex');
    const [ivHex, encryptedHex, authTagHex] = combined.split(':');
    
    if (!ivHex || !encryptedHex || !authTagHex) {
      console.warn('[DECRYPTION] Invalid encrypted format');
      return encrypted; // Return as-is if format is invalid
    }
    
    const key = Buffer.from(ENCRYPTION_KEY, 'hex');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    
    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  } catch (err) {
    console.error('[DECRYPTION_ERROR]', err.message);
    return encrypted; // Return encrypted value if decryption fails
  }
};

/**
 * Check if a field is encrypted
 * Simple heuristic: check if it can be decoded from base64 and contains expected format
 */
export const isEncrypted = (value) => {
  if (!value || typeof value !== 'string') return false;
  
  try {
    const combined = Buffer.from(value, 'base64').toString('hex');
    const parts = combined.split(':');
    return parts.length === 3 && parts[0].length === 32 && parts[2].length === 32; // IV (16 bytes) and authTag (16 bytes)
  } catch {
    return false;
  }
};
