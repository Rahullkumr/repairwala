// GET /files/...: photos, voice notes and QR codes from data/files (the token check runs first).
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, resolve, sep } from 'node:path';
import { FILES_DIR } from '../config.js';
import { HttpError } from '../lib/http.js';

const TYPES = { '.jpg': 'image/jpeg', '.png': 'image/png', '.mp3': 'audio/mpeg' };

export default async function fileRoutes(app) {
  app.get('/files/*', async (req, reply) => {
    const rel = req.params['*'];
    const path = resolve(FILES_DIR, rel);
    // Whatever the URL says, the file must sit inside data/files.
    if (rel.includes('\0') || !path.startsWith(FILES_DIR + sep)) throw new HttpError(404, 'not found');
    const type = TYPES[extname(path).toLowerCase()];
    const info = await stat(path).catch(() => null);
    if (!type || !info?.isFile()) throw new HttpError(404, 'not found');
    return reply.type(type).header('Content-Length', info.size).send(createReadStream(path));
  });
}
