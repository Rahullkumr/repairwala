// GET /api/health: which helpers answer, so the app can show what is working.
import { SHOP_NAME } from '../config.js';
import { whisperUp } from '../services/whisper.js';
import { ollamaUp } from '../services/ollama.js';
import { ttsEnabled } from '../services/elevenlabs.js';
import { upiReady } from '../services/qr.js';

export default async function healthRoutes(app) {
  app.get('/api/health', async () => {
    const [whisper, ollama] = await Promise.all([whisperUp(), ollamaUp()]);
    return { ok: true, whisper, ollama, tts: ttsEnabled, shop_name: SHOP_NAME, upi_ready: upiReady };
  });
}
