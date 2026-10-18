// POST /api/transcribe: the recorded WAV goes to whisper.cpp, the Hindi text comes back.
import { transcribe } from '../services/whisper.js';
import { HttpError, readFile } from '../lib/http.js';

export default async function transcribeRoutes(app) {
  app.post('/api/transcribe', async (req) => {
    const wav = await readFile(req, 'audio');
    const started = Date.now();
    let text;
    try {
      text = await transcribe(wav);
    } catch (err) {
      req.log.error(err);
      throw new HttpError(503, `Whisper is not available: ${err.message}`);
    }
    return { text, seconds: Math.round((Date.now() - started) / 100) / 10 };
  });
}
