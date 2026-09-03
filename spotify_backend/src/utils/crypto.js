/**
 * crypto.js utility
 * =================
 * AES-256-GCM encryption/decryption for OAuth tokens stored at rest.
 * Uses ENCRYPTION_KEY from environment (must be 32 bytes / 64 hex chars).
 */

const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32; // 256 bits

function getKey() {
  const raw = process.env.ENCRYPTION_KEY;
  if (!raw) {
    // In development without a key, use a placeholder (NOT secure for production)
    console.warn('[crypto] WARNING: ENCRYPTION_KEY not set. Tokens are not encrypted!');
    return Buffer.alloc(KEY_LENGTH, 0);
  }
  // Accept either raw string (padded/truncated to 32 bytes) or 64-char hex
  if (raw.length === 64) {
    return Buffer.from(raw, 'hex');
  }
  return Buffer.from(raw.padEnd(KEY_LENGTH, '0').substring(0, KEY_LENGTH));
}

/**
 * Encrypt a plaintext string (e.g., OAuth access token).
 * @param {string} plaintext
 * @returns {string} - iv:authTag:ciphertext (all hex)
 */
function encryptToken(plaintext) {
  if (!plaintext) return plaintext;
  try {
    const key = getKey();
    const iv  = crypto.randomBytes(12); // GCM nonce
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

    const encrypted = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted.toString('hex')}`;
  } catch (err) {
    console.error('[crypto] encryptToken error:', err.message);
    return plaintext; // Fallback: store unencrypted (not ideal, but doesn't break auth)
  }
}

/**
 * Decrypt a token encrypted by encryptToken().
 * @param {string} encrypted - iv:authTag:ciphertext
 * @returns {string} - Original plaintext
 */
function decryptToken(encrypted) {
  if (!encrypted || !encrypted.includes(':')) return encrypted;
  try {
    const [ivHex, authTagHex, dataHex] = encrypted.split(':');
    const key = getKey();
    const iv  = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const data = Buffer.from(dataHex, 'hex');

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
  } catch (err) {
    console.error('[crypto] decryptToken error:', err.message);
    return encrypted; // Return as-is if decryption fails
  }
}

module.exports = { encryptToken, decryptToken };
