// Small helpers shared by the routes: errors in the contract's shape and multipart reading.

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export const bad = (message) => new HttpError(400, message);

// Reads one uploaded file field from a multipart request. Returns a Buffer, or throws 400.
export async function readFile(req, field) {
  const file = await req.file();
  if (!file || file.fieldname !== field) throw bad(`multipart field "${field}" is required`);
  const buf = await file.toBuffer();
  if (!buf.length) throw bad(`"${field}" is empty`);
  return buf;
}

// Whole non-negative rupees from a number or numeric string; null/empty -> null; else throws.
export function money(v, field) {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'string' ? Number(v) : v;
  if (!Number.isInteger(n) || n < 0 || n > 100000000) throw bad(`${field} must be a whole number of rupees`);
  return n;
}

export function text(v, field, max = 2000) {
  if (v === null || v === undefined) return null;
  if (typeof v !== 'string') throw bad(`${field} must be text`);
  const s = v.trim();
  if (s.length > max) throw bad(`${field} is too long`);
  return s || null;
}

// A 10-digit Indian mobile number. Accepts +91 / 0 prefixes and spaces. Returns null if empty.
export function phone(v) {
  if (v === null || v === undefined || String(v).trim() === '') return null;
  let d = String(v).replace(/\D/g, '');
  if (d.length === 12 && d.startsWith('91')) d = d.slice(2);
  else if (d.length === 11 && d.startsWith('0')) d = d.slice(1);
  // Indian mobile numbers are 10 digits starting with 6, 7, 8 or 9.
  if (!/^[6-9]\d{9}$/.test(d)) throw bad('phone must be a 10-digit mobile number starting with 6-9');
  return d;
}

export function date(v, field) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v) || Number.isNaN(Date.parse(v))) {
    throw bad(`${field} must be YYYY-MM-DD`);
  }
  return v;
}
