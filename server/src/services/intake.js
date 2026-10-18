// Runs the intake prompt on a Whisper transcript and turns the model's answer into the
// contract's fields. Everything the model says is checked here; dates are worked out by code.
import { chatJSON } from './ollama.js';
import { INTAKE_SCHEMA, intakeSystemPrompt, intakeUserPrompt } from '../prompts/intake.js';
import { APPLIANCE_KEYS } from '../lib/appliances.js';
import { resolvePickupDate } from '../lib/dates.js';

const str = (v) => (typeof v === 'string' && v.trim() ? v.trim() : null);

// Whole rupees between 10 and 2,00,000, else null.
export function cleanAmount(v) {
  return Number.isInteger(v) && v >= 10 && v <= 200000 ? v : null;
}

export async function parseIntake(text, kind = 'intake', now = new Date()) {
  const { result: r, stats } = await chatJSON({
    system: intakeSystemPrompt(kind),
    user: intakeUserPrompt(text, kind),
    schema: INTAKE_SCHEMA,
    options: { temperature: 0.2, num_predict: 600 },
  });
  const pickup = r.pickup || {};
  // A quick job is paid for already: whichever amount slot the model used, it is the final amount.
  const quick = kind === 'quick';
  const amount = cleanAmount(quick ? (r.final_amount ?? r.estimate) : (r.estimate ?? r.final_amount));
  return {
    name: str(r.name),
    village: str(r.village),
    appliance: APPLIANCE_KEYS.includes(r.appliance) ? r.appliance : 'other',
    complaint: str(r.complaint),
    diagnosis: str(r.diagnosis),
    work_done: str(r.work_done),
    estimate: quick ? null : amount,
    final_amount: quick ? amount : null,
    pickup_date: resolvePickupDate(pickup, now),
    pickup_said: str(pickup.said),
    seconds: stats.seconds,
  };
}
