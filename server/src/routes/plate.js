// POST /api/read-plate: a photo of the rating plate in, brand / model / rating / serial out.
import { chatJSON } from '../services/ollama.js';
import { PLATE_SCHEMA, PLATE_SYSTEM, PLATE_USER } from '../prompts/plate.js';
import { VISION_MODEL } from '../config.js';
import { HttpError, readFile } from '../lib/http.js';

const clean = (v) => (typeof v === 'string' && v.trim() && !/^(null|none|n\/a|unknown)$/i.test(v.trim())
  ? v.trim().slice(0, 60) : null);

export default async function plateRoutes(app) {
  app.post('/api/read-plate', async (req) => {
    const photo = await readFile(req, 'photo');
    try {
      const { result: r, stats } = await chatJSON({
        model: VISION_MODEL,
        system: PLATE_SYSTEM,
        user: PLATE_USER,
        schema: PLATE_SCHEMA,
        images: [photo.toString('base64')],
        options: { temperature: 0.1, num_predict: 300 },
      });
      return {
        brand: clean(r.brand), model: clean(r.model), rating: clean(r.rating), serial: clean(r.serial),
        seconds: stats.seconds,
      };
    } catch (err) {
      req.log.error(err);
      throw new HttpError(503, `The AI model is not available: ${err.message}`);
    }
  });
}
