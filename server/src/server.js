// Local server for Repairwala: job cards in SQLite, Whisper for speech, Gemma for
// reading the speech, ElevenLabs for the "ready" voice note. Runs on the shop laptop.
import { networkInterfaces } from 'node:os';
import { timingSafeEqual } from 'node:crypto';
import Fastify from 'fastify';
import multipart from '@fastify/multipart';
import { HOST, PORT, SHOP_TOKEN, TOKEN_FROM_ENV, OLLAMA_MODEL, VISION_MODEL, UPI_ID, TIMEZONE } from './config.js';
import { warmUp } from './services/ollama.js';
import { ttsEnabled } from './services/elevenlabs.js';
import { todayString } from './lib/dates.js';
import healthRoutes from './routes/health.js';
import transcribeRoutes from './routes/transcribe.js';
import parseRoutes from './routes/parse.js';
import plateRoutes from './routes/plate.js';
import customerRoutes from './routes/customers.js';
import jobRoutes from './routes/jobs.js';
import fileRoutes from './routes/files.js';

const app = Fastify({ logger: true });

await app.register(multipart, { limits: { fileSize: 25 * 1024 * 1024, files: 4 } });

// Every /api and /files request needs the shop token.
const token = Buffer.from(SHOP_TOKEN);
app.addHook('onRequest', async (req, reply) => {
  if (!req.url.startsWith('/api/') && !req.url.startsWith('/files/')) return;
  const sent = Buffer.from(String(req.headers['x-shop-token'] || ''));
  if (sent.length !== token.length || !timingSafeEqual(sent, token)) {
    return reply.code(401).send({ error: 'bad token' });
  }
});

// Errors always look like {"error": "..."}.
app.setErrorHandler((err, req, reply) => {
  const status = err.status || err.statusCode || 500;
  if (status >= 500) req.log.error(err);
  reply.code(status).send({ error: status >= 500 && !err.status ? 'server error' : err.message });
});
app.setNotFoundHandler((req, reply) => reply.code(404).send({ error: 'not found' }));

await app.register(healthRoutes);
await app.register(transcribeRoutes);
await app.register(parseRoutes);
await app.register(plateRoutes);
await app.register(customerRoutes);
await app.register(jobRoutes);
await app.register(fileRoutes);

await app.listen({ host: HOST, port: PORT });
if (!TOKEN_FROM_ENV) {
  app.log.warn('!!! SHOP_TOKEN is not set. Using a random token for this run only. Put SHOP_TOKEN in .env !!!');
  app.log.warn(`!!! Token for this run: ${SHOP_TOKEN} !!!`);
}
app.log.info(`Today in the shop (${TIMEZONE}): ${todayString()}`);
app.log.info(ttsEnabled ? 'ElevenLabs voice enabled' : 'ELEVENLABS_API_KEY not set, no voice notes');
app.log.info(UPI_ID ? 'UPI QR enabled' : 'UPI_ID not set, no payment QR');
if (HOST === '0.0.0.0') {
  const lan = Object.values(networkInterfaces()).flat()
    .filter((i) => i.family === 'IPv4' && !i.internal).map((i) => `http://${i.address}:${PORT}`);
  app.log.info(`Server for the phone app (same Wi-Fi): ${lan.join('  ')}`);
}
warmUp()
  .then(() => app.log.info(`Model ${OLLAMA_MODEL} loaded${VISION_MODEL !== OLLAMA_MODEL ? `, plates read by ${VISION_MODEL}` : ''}`))
  .catch((err) => app.log.warn(`Model warm-up failed, is Ollama running? ${err.message}`));
