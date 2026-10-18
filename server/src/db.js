// SQLite storage (built-in node:sqlite) for customers and jobs, and the mapping from rows
// to the Customer and Job objects of the API contract (docs/api.md).
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { DATA_DIR, FILES_DIR } from './config.js';
import { APPLIANCES } from './lib/appliances.js';

mkdirSync(resolve(FILES_DIR, 'jobs'), { recursive: true });
mkdirSync(resolve(FILES_DIR, 'customers'), { recursive: true });

const db = new DatabaseSync(resolve(DATA_DIR, 'shop.db'));
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
db.exec(`
  CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT UNIQUE,
    name TEXT,
    village TEXT,
    photo_url TEXT,
    created_at TEXT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER REFERENCES customers(id),
    kind TEXT NOT NULL DEFAULT 'intake',
    appliance TEXT NOT NULL DEFAULT 'other',
    brand TEXT, model TEXT, rating TEXT, serial TEXT,
    complaint TEXT, diagnosis TEXT, work_done TEXT,
    estimate INTEGER, final_amount INTEGER,
    pickup_date TEXT,
    status TEXT NOT NULL DEFAULT 'received',
    paid INTEGER NOT NULL DEFAULT 0,
    pay_method TEXT,
    transcript TEXT,
    machine_photo_url TEXT, plate_photo_url TEXT,
    created_at TEXT NOT NULL,
    repaired_at TEXT, delivered_at TEXT, notified_at TEXT
  );
  CREATE INDEX IF NOT EXISTS jobs_customer ON jobs(customer_id);
  CREATE INDEX IF NOT EXISTS jobs_status ON jobs(status);
`);

const now = () => new Date().toISOString();

const JOB_SELECT = `
  SELECT j.*, c.id AS c_id, c.phone AS c_phone, c.name AS c_name, c.village AS c_village,
         c.photo_url AS c_photo_url, c.created_at AS c_created_at
  FROM jobs j LEFT JOIN customers c ON c.id = j.customer_id`;

function customerOf(row) {
  if (row.id === undefined) return null;
  return {
    id: row.id, phone: row.phone, name: row.name, village: row.village,
    photo_url: row.photo_url, created_at: row.created_at,
  };
}

function jobOf(r) {
  return {
    id: r.id,
    customer: r.c_id == null ? null : customerOf({
      id: r.c_id, phone: r.c_phone, name: r.c_name, village: r.c_village,
      photo_url: r.c_photo_url, created_at: r.c_created_at,
    }),
    kind: r.kind,
    appliance: r.appliance, brand: r.brand, model: r.model, rating: r.rating, serial: r.serial,
    complaint: r.complaint, diagnosis: r.diagnosis, work_done: r.work_done,
    estimate: r.estimate, final_amount: r.final_amount,
    pickup_date: r.pickup_date,
    status: r.status, paid: Boolean(r.paid), pay_method: r.pay_method,
    transcript: r.transcript,
    machine_photo_url: r.machine_photo_url, plate_photo_url: r.plate_photo_url,
    created_at: r.created_at, repaired_at: r.repaired_at,
    delivered_at: r.delivered_at, notified_at: r.notified_at,
  };
}

// ---- customers ----

export function getCustomerByPhone(phone) {
  const row = db.prepare('SELECT * FROM customers WHERE phone = ?').get(phone);
  return row ? customerOf(row) : null;
}

// Finds the customer by phone or creates one. name/village update the customer when given.
export function upsertCustomer({ phone, name, village }) {
  const existing = db.prepare('SELECT * FROM customers WHERE phone = ?').get(phone);
  if (!existing) {
    const info = db.prepare('INSERT INTO customers (phone, name, village, created_at) VALUES (?, ?, ?, ?)')
      .run(phone, name ?? null, village ?? null, now());
    return Number(info.lastInsertRowid);
  }
  if (name || village) {
    db.prepare('UPDATE customers SET name = COALESCE(?, name), village = COALESCE(?, village) WHERE id = ?')
      .run(name ?? null, village ?? null, existing.id);
  }
  return existing.id;
}

export function setCustomerPhoto(id, url) {
  db.prepare('UPDATE customers SET photo_url = ? WHERE id = ?').run(url, id);
}

// ---- jobs ----

export function getJob(id) {
  const row = db.prepare(`${JOB_SELECT} WHERE j.id = ?`).get(id);
  return row ? jobOf(row) : null;
}

export function jobsOfCustomer(customerId, exceptJobId = 0) {
  return db.prepare(`${JOB_SELECT} WHERE j.customer_id = ? AND j.id != ? ORDER BY j.id DESC`)
    .all(customerId, exceptJobId).map(jobOf);
}

const JOB_COLUMNS = [
  'customer_id', 'kind', 'appliance', 'brand', 'model', 'rating', 'serial',
  'complaint', 'diagnosis', 'work_done', 'estimate', 'final_amount', 'pickup_date',
  'status', 'paid', 'pay_method', 'transcript', 'machine_photo_url', 'plate_photo_url',
  'repaired_at', 'delivered_at', 'notified_at',
];

// `fields` uses job column names; booleans become 0/1. Returns the new job id.
export function insertJob(fields) {
  const cols = ['created_at', ...Object.keys(fields).filter((k) => JOB_COLUMNS.includes(k))];
  const values = cols.map((c) => (c === 'created_at' ? now() : toDb(fields[c])));
  const info = db.prepare(`INSERT INTO jobs (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`)
    .run(...values);
  return Number(info.lastInsertRowid);
}

export function updateJob(id, fields) {
  const cols = Object.keys(fields).filter((k) => JOB_COLUMNS.includes(k));
  if (!cols.length) return;
  db.prepare(`UPDATE jobs SET ${cols.map((c) => `${c} = ?`).join(', ')} WHERE id = ?`)
    .run(...cols.map((c) => toDb(fields[c])), id);
}

const toDb = (v) => (typeof v === 'boolean' ? Number(v) : v ?? null);

export const nowIso = now;

// status: 'open' (received + repaired, by pickup date), 'done' or 'all' (newest first).
// q matches phone, name, village, appliance (key or Hindi label) and brand, as a substring.
export function listJobs({ status = 'open', q = '' } = {}) {
  const where = [];
  const args = [];
  if (status === 'open') where.push("j.status IN ('received', 'repaired')");
  else if (status === 'done') where.push("j.status IN ('delivered', 'returned')");

  const needle = q.trim().toLowerCase();
  if (needle) {
    const like = `%${needle.replace(/[\\%_]/g, '\\$&')}%`;
    const keys = Object.entries(APPLIANCES)
      .filter(([key, label]) => key.includes(needle) || label.toLowerCase().includes(needle))
      .map(([key]) => key);
    const parts = ['c.phone LIKE ?', 'c.name LIKE ?', 'c.village LIKE ?', 'j.brand LIKE ?'].map((p) => `${p} ESCAPE '\\'`);
    args.push(like, like, like, like);
    if (keys.length) {
      parts.push(`j.appliance IN (${keys.map(() => '?').join(', ')})`);
      args.push(...keys);
    }
    where.push(`(${parts.join(' OR ')})`);
  }

  const order = status === 'open' ? 'j.pickup_date IS NULL, j.pickup_date ASC, j.id ASC' : 'j.id DESC';
  const sql = `${JOB_SELECT} ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY ${order}`;
  return db.prepare(sql).all(...args).map(jobOf);
}
