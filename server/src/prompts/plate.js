// The prompt and JSON schema for reading a machine's rating plate (name plate) photo.
const nullableString = { type: ['string', 'null'] };

export const PLATE_SCHEMA = {
  type: 'object',
  properties: {
    brand: nullableString,
    model: nullableString,
    rating: nullableString,
    serial: nullableString,
  },
  required: ['brand', 'model', 'rating', 'serial'],
};

export const PLATE_SYSTEM = `You read the rating plate (name plate label) on an electrical machine such as a water pump, motor, fan or mixer-grinder, from a photo.

Return JSON only with: brand, model, rating, serial.
Rules:
1. Copy only text that is actually visible and readable on the label or plate. Never guess.
2. If a field is not on the plate or not readable, use null.
3. Never guess the brand from the look or shape of the machine. The brand must be printed text on the plate or logo.
4. "rating" is the power rating exactly as printed, short, for example "1 HP", "750 W", "230V 0.5A". Keep it under 30 characters.
5. "model" is the model name or number; "serial" is the serial / SR. No. / batch number. Keep letters and digits exactly as printed.
6. If the picture is not a plate at all, return all four as null.`;

export const PLATE_USER = 'Read this rating plate.';
