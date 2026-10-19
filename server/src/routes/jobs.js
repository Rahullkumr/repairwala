// Jobs: create, list, read, update, delete, photos, and the "machine is ready" notification.
import { writeFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import {
  getJob, listJobs, insertJob, updateJob, upsertCustomer, setCustomerPhoto, jobsOfCustomer, nowIso,
  setCustomerDetails, deleteCustomerIfUnused, deleteJob,
} from '../db.js';
import { FILES_DIR, UPI_ID } from '../config.js';
import { APPLIANCE_KEYS, PAY_METHODS, STATUSES } from '../lib/appliances.js';
import { HttpError, bad, money, text, phone as cleanPhone, date } from '../lib/http.js';
import { buildText, buildSpeech, waPhone } from '../lib/messages.js';
import { speakToBuffer, ttsEnabled } from '../services/elevenlabs.js';
import { upiLink, qrPng } from '../services/qr.js';

const jobFile = (id, suffix) => resolve(FILES_DIR, 'jobs', `${id}-${suffix}`);

// Checks the editable fields shared by create and PATCH. Returns only the keys that were sent.
function cleanFields(body, keys) {
  const out = {};
  const has = (k) => keys.includes(k) && body[k] !== undefined;
  for (const k of ['brand', 'model', 'rating', 'serial']) if (has(k)) out[k] = text(body[k], k, 100);
  for (const k of ['complaint', 'diagnosis', 'work_done']) if (has(k)) out[k] = text(body[k], k);
  if (has('estimate')) out.estimate = money(body.estimate, 'estimate');
  if (has('final_amount')) out.final_amount = money(body.final_amount, 'final_amount');
  if (has('pickup_date')) out.pickup_date = date(body.pickup_date, 'pickup_date');
  if (has('appliance')) {
    if (!APPLIANCE_KEYS.includes(body.appliance)) throw bad(`appliance must be one of: ${APPLIANCE_KEYS.join(', ')}`);
    out.appliance = body.appliance;
  }
  if (has('paid')) {
    if (typeof body.paid !== 'boolean') throw bad('paid must be true or false');
    out.paid = body.paid;
  }
  if (has('pay_method')) {
    if (body.pay_method !== null && !PAY_METHODS.includes(body.pay_method)) throw bad('pay_method must be cash, upi or null');
    out.pay_method = body.pay_method;
  }
  return out;
}

const EDITABLE = ['brand', 'model', 'rating', 'serial', 'complaint', 'diagnosis', 'work_done', 'estimate',
  'final_amount', 'pickup_date', 'appliance', 'paid', 'pay_method'];

export default async function jobRoutes(app) {
  app.post('/api/jobs', async (req, reply) => {
    if (!req.isMultipart()) throw bad('send multipart/form-data with a "data" field');
    let data = null;
    const photos = {};
    for await (const part of req.parts()) {
      if (part.type === 'file') {
        const buf = await part.toBuffer();
        if (['machine_photo', 'plate_photo', 'customer_photo'].includes(part.fieldname) && buf.length) {
          photos[part.fieldname] = buf;
        }
      } else if (part.fieldname === 'data') {
        // A part sent as application/json arrives already parsed.
        try { data = typeof part.value === 'string' ? JSON.parse(part.value) : part.value; } catch { throw bad('data must be valid JSON'); }
      }
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw bad('field "data" (JSON object) is required');

    const kind = data.kind ?? 'intake';
    if (kind !== 'intake' && kind !== 'quick') throw bad('kind must be "intake" or "quick"');
    // Every job needs a customer (phone and name) so the shop builds up history,
    // and a machine type; a quick fix also needs what was charged.
    const phone = cleanPhone(data.phone);
    if (!phone) throw bad('phone is required');

    const fields = cleanFields(data, EDITABLE);
    const name = text(data.name, 'name', 100);
    if (!name) throw bad('name is required');
    if (!fields.appliance) throw bad('appliance is required');
    if (kind === 'quick' && fields.final_amount == null) throw bad('final_amount is required for a quick job');
    const village = text(data.village, 'village', 100);
    const customerId = phone ? upsertCustomer({ phone, name, village }) : null;

    const quick = kind === 'quick';
    const stamp = nowIso();
    const id = insertJob({
      ...fields,
      customer_id: customerId,
      kind,
      appliance: fields.appliance ?? 'other',
      transcript: text(data.transcript, 'transcript', 5000),
      paid: fields.paid ?? false,
      // A quick job is fixed and handed over on the spot.
      status: quick ? 'delivered' : 'received',
      repaired_at: quick ? stamp : null,
      delivered_at: quick ? stamp : null,
    });

    const urls = {};
    if (photos.machine_photo) {
      await writeFile(jobFile(id, 'machine.jpg'), photos.machine_photo);
      urls.machine_photo_url = `/files/jobs/${id}-machine.jpg`;
    }
    if (photos.plate_photo) {
      await writeFile(jobFile(id, 'plate.jpg'), photos.plate_photo);
      urls.plate_photo_url = `/files/jobs/${id}-plate.jpg`;
    }
    updateJob(id, urls);
    if (photos.customer_photo && customerId) {
      await writeFile(resolve(FILES_DIR, 'customers', `${customerId}.jpg`), photos.customer_photo);
      setCustomerPhoto(customerId, `/files/customers/${customerId}.jpg`);
    }
    return reply.code(201).send(getJob(id));
  });

  app.get('/api/jobs', async (req) => {
    const { status = 'open', q = '' } = req.query;
    if (!['open', 'done', 'all'].includes(status)) throw bad('status must be open, done or all');
    return { jobs: listJobs({ status, q: String(q) }) };
  });

  app.get('/api/jobs/:id', async (req) => {
    const job = findJob(req.params.id);
    return { ...job, history: job.customer ? jobsOfCustomer(job.customer.id, job.id) : [] };
  });

  app.patch('/api/jobs/:id', async (req) => {
    const job = findJob(req.params.id);
    const body = req.body;
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw bad('JSON body required');
    const fields = cleanFields(body, [...EDITABLE, 'complaint']);
    if (body.appliance === null) throw bad('appliance is required');
    const quickAmount = fields.final_amount !== undefined ? fields.final_amount : job.final_amount;
    if (job.kind === 'quick' && quickAmount == null) throw bad('final_amount is required for a quick job');
    if (body.status !== undefined) {
      if (!STATUSES.includes(body.status)) throw bad(`status must be one of: ${STATUSES.join(', ')}`);
      Object.assign(fields, statusChange(job, body.status));
    }

    // Customer: a new phone moves the job to that customer (found or created);
    // name and village are set exactly as sent, and the name can't be emptied.
    const oldCustomerId = job.customer?.id ?? null;
    let customerId = oldCustomerId;
    if (body.phone !== undefined) {
      const phone = cleanPhone(body.phone);
      if (!phone) throw bad('phone is required');
      customerId = upsertCustomer({ phone });
      fields.customer_id = customerId;
    }
    if (body.name !== undefined || body.village !== undefined) {
      if (!customerId) throw bad('phone is required');
      const name = body.name !== undefined ? text(body.name, 'name', 100) : job.customer?.name;
      if (!name) throw bad('name is required');
      const village = body.village !== undefined ? text(body.village, 'village', 100) : job.customer?.village;
      setCustomerDetails(customerId, { name, village });
    }

    updateJob(job.id, fields);
    if (customerId !== oldCustomerId) await removeCustomerIfUnused(oldCustomerId);
    return getJob(job.id);
  });

  // Replaces any of the job's photos (multipart: machine_photo, plate_photo, customer_photo).
  app.post('/api/jobs/:id/photos', async (req) => {
    const job = findJob(req.params.id);
    if (!req.isMultipart()) throw bad('send multipart/form-data');
    const urls = {};
    for await (const part of req.parts()) {
      if (part.type !== 'file') continue;
      const buf = await part.toBuffer();
      if (!buf.length) continue;
      if (part.fieldname === 'machine_photo' || part.fieldname === 'plate_photo') {
        const kind = part.fieldname === 'machine_photo' ? 'machine' : 'plate';
        await writeFile(jobFile(job.id, `${kind}.jpg`), buf);
        urls[`${kind}_photo_url`] = `/files/jobs/${job.id}-${kind}.jpg`;
      } else if (part.fieldname === 'customer_photo' && job.customer) {
        await writeFile(resolve(FILES_DIR, 'customers', `${job.customer.id}.jpg`), buf);
        setCustomerPhoto(job.customer.id, `/files/customers/${job.customer.id}.jpg`);
      }
    }
    updateJob(job.id, urls);
    return getJob(job.id);
  });

  // Deletes the job and its files; a customer left with no jobs is removed too.
  app.delete('/api/jobs/:id', async (req, reply) => {
    const job = findJob(req.params.id);
    deleteJob(job.id);
    await Promise.all(['machine.jpg', 'plate.jpg', 'ready.mp3', 'qr.png']
      .map((f) => rm(jobFile(job.id, f), { force: true })));
    await removeCustomerIfUnused(job.customer?.id);
    return reply.code(204).send();
  });

  app.post('/api/jobs/:id/notify', async (req) => {
    const job = findJob(req.params.id);
    const body = req.body || {};
    // The amount and work done are saved first, so the message and the card agree.
    const fields = cleanFields(body, ['final_amount', 'work_done']);
    if (job.status === 'received') Object.assign(fields, statusChange(job, 'repaired'));
    updateJob(job.id, fields);

    const fresh = getJob(job.id);
    const amount = fresh.final_amount ?? fresh.estimate ?? null;

    // Old voice note and QR belong to an older amount; drop them before making new ones.
    await Promise.all([rm(jobFile(job.id, 'ready.mp3'), { force: true }), rm(jobFile(job.id, 'qr.png'), { force: true })]);

    let qrUrl = null;
    let link = null;
    if (UPI_ID && amount) {
      link = upiLink(job.id, amount);
      await writeFile(jobFile(job.id, 'qr.png'), await qrPng(link));
      qrUrl = `/files/jobs/${job.id}-qr.png`;
    }

    const speech = buildSpeech(fresh, amount);
    let voiceUrl = null;
    if (ttsEnabled) {
      try {
        await writeFile(jobFile(job.id, 'ready.mp3'), await speakToBuffer(speech));
        voiceUrl = `/files/jobs/${job.id}-ready.mp3`;
      } catch (err) {
        req.log.error(err, 'voice note failed, sending without it');
      }
    }

    updateJob(job.id, { notified_at: nowIso() });
    return {
      text: buildText(fresh, amount, Boolean(qrUrl)),
      speech,
      voice_url: voiceUrl,
      qr_url: qrUrl,
      upi_link: link,
      wa_phone: waPhone(fresh.customer?.phone),
    };
  });
}

async function removeCustomerIfUnused(customerId) {
  if (deleteCustomerIfUnused(customerId)) {
    await rm(resolve(FILES_DIR, 'customers', `${customerId}.jpg`), { force: true });
  }
}

function findJob(rawId) {
  const id = Number(rawId);
  const job = Number.isInteger(id) ? getJob(id) : null;
  if (!job) throw new HttpError(404, 'job not found');
  return job;
}

// Status column plus the time stamps the contract wants for each status.
function statusChange(job, status) {
  const out = { status };
  const stamp = nowIso();
  if (status === 'repaired') out.repaired_at = stamp;
  if (status === 'delivered' || status === 'returned') out.delivered_at = stamp;
  return out;
}
