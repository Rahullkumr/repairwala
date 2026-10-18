// POST /api/parse-intake: Hindi transcript in, job card fields out (nothing invented).
import { parseIntake } from '../services/intake.js';
import { HttpError, bad } from '../lib/http.js';

export default async function parseRoutes(app) {
  app.post('/api/parse-intake', async (req) => {
    const { text, kind = 'intake' } = req.body || {};
    if (typeof text !== 'string' || !text.trim()) throw bad('text is required');
    if (text.length > 4000) throw bad('text is too long');
    if (kind !== 'intake' && kind !== 'quick') throw bad('kind must be "intake" or "quick"');
    try {
      return await parseIntake(text.trim(), kind);
    } catch (err) {
      req.log.error(err);
      throw new HttpError(503, `The AI model is not available: ${err.message}`);
    }
  });
}
