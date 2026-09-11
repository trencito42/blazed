'use strict';

const crypto = require('crypto');

const KEY_LENGTH = 32;
const SCRYPT_OPTIONS = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

function hashPassword(password) {
  if (typeof password !== 'string' || !password.length) return null;
  const salt = crypto.randomBytes(16);
  const derived = crypto.scryptSync(password, salt, KEY_LENGTH, SCRYPT_OPTIONS);
  return `$scrypt$${SCRYPT_OPTIONS.N}$${SCRYPT_OPTIONS.r}$${SCRYPT_OPTIONS.p}$${salt.toString('base64')}$${derived.toString('base64')}`;
}

function verifyPassword(password, encoded) {
  if (typeof password !== 'string' || typeof encoded !== 'string') return false;
  const parts = encoded.split('$');
  if (parts.length !== 7 || parts[1] !== 'scrypt') return false;
  const N = Number(parts[2]);
  const r = Number(parts[3]);
  const p = Number(parts[4]);
  if (N !== SCRYPT_OPTIONS.N || r !== SCRYPT_OPTIONS.r || p !== SCRYPT_OPTIONS.p) return false;
  try {
    const salt = Buffer.from(parts[5], 'base64');
    const expected = Buffer.from(parts[6], 'base64');
    if (expected.length !== KEY_LENGTH) return false;
    const actual = crypto.scryptSync(password, salt, expected.length, { N, r, p, maxmem: SCRYPT_OPTIONS.maxmem });
    return crypto.timingSafeEqual(actual, expected);
  } catch (_) {
    return false;
  }
}

function randomToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value || ''), 'utf8').digest('hex');
}

exports('HashPassword', hashPassword);
exports('VerifyPassword', verifyPassword);
exports('GenerateQuickToken', randomToken);
exports('HashToken', sha256);
