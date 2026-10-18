// The prompt and JSON schema that turn the electrician's spoken Hindi into job-card fields.
// The model only copies what was said. Dates are worked out later by code (lib/dates.js).
import { APPLIANCE_KEYS } from '../lib/appliances.js';

const nullableString = { type: ['string', 'null'] };
const nullableInt = { type: ['integer', 'null'] };

export const INTAKE_SCHEMA = {
  type: 'object',
  properties: {
    name: nullableString,
    village: nullableString,
    appliance: { type: 'string', enum: APPLIANCE_KEYS },
    complaint: nullableString,
    diagnosis: nullableString,
    work_done: nullableString,
    estimate: nullableInt,
    final_amount: nullableInt,
    pickup: {
      type: 'object',
      properties: {
        said: nullableString,
        days_from_today: nullableInt,
        weekday: { type: ['string', 'null'], enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', null] },
        day_of_month: nullableInt,
      },
      required: ['said', 'days_from_today', 'weekday', 'day_of_month'],
    },
  },
  required: ['name', 'village', 'appliance', 'complaint', 'diagnosis', 'work_done', 'estimate', 'final_amount', 'pickup'],
};

export function intakeSystemPrompt(kind) {
  const amountRule = kind === 'quick'
    ? `This is a QUICK job: the machine was fixed while the customer waited. The amount said is the money charged: put it in "final_amount" and leave "estimate" null. "work_done" is what was done (for example "स्विच बदला"). "diagnosis" is usually null.`
    : `This is an INTAKE job: the machine is being left at the shop. The amount said is the price the electrician expects: put it in "estimate" and leave "final_amount" null. "work_done" is null. "diagnosis" is what the electrician found or says must be done (for example "वाइंडिंग जल गई है", "कैपेसिटर बदलना पड़ेगा").`;

  return `You read what a village electrician in India said into his phone about one repair job, and you fill in a job card. He speaks Hindi; the text comes from speech recognition, so it is in Devanagari (sometimes Devanagari digits like १२३, sometimes English words written in Devanagari, and sometimes odd spellings like पंदरह for पंद्रह).

Return JSON only. Rules:
1. Copy only what was said. NEVER invent a name, village, amount or date. If something was not said, use null. A job with no customer name is normal: name null.
2. "name" is the customer's name and "village" the customer's village or town, written in Devanagari as heard (for example "रामेश्वर महतो", "पिठोरिया"). "से" after a place only means "from"; do not include it in the village.
3. "complaint" is the customer's problem in short simple Hindi (for example "मोटर नहीं चल रहा", "धीरे चलता है"). Use the speaker's own words. null if not said.
4. ${amountRule}
5. Amounts are integers in rupees. Convert Hindi number words to digits: सौ=100, डेढ़ सौ=150, ढाई सौ=250, साढ़े तीन सौ=350, दो सौ=200, पंद्रह/पंदरह सौ=1500, बारह सौ=1200, दो हज़ार=2000, ढाई हज़ार=2500, पाँच सौ=500, हज़ार=1000. Devanagari digits too (१५०० = 1500). Words like रुपये/रुपए/रुपया are not part of the number. If no amount was said, use null. Never guess one.
6. "pickup" is when the customer should come to take the machine. It is always in the future (or today).
   - "said": the exact words the electrician used for the date (for example "परसों", "कल शाम तक", "बुधवार को"). null if no date was said.
   - "days_from_today": कल = 1, परसों = 2, तरसों/नरसों = 3, आज / आज शाम / शाम तक / आज ही = 0, "दो दिन में" = 2, "चार दिन बाद" = 4, "हफ्ते भर में" = 7. null if no such word.
   - "weekday": if a weekday name is said (सोमवार=monday, मंगलवार=tuesday, बुधवार=wednesday, गुरुवार/बृहस्पतिवार=thursday, शुक्रवार=friday, शनिवार=saturday, रविवार/इतवार=sunday) give it in English lowercase and leave days_from_today null. Otherwise null.
   - "day_of_month": only when a date number is said ("15 तारीख को" -> 15). Otherwise null.
   - Use only one of days_from_today, weekday, day_of_month. Do not work out the real calendar date.
   - A time of day alone ("शाम को") with no day means days_from_today 0 only if the words आज or शाम तक were said; otherwise everything is null.
7. "appliance" must be one of these keys, the closest match to the machine named: ${APPLIANCE_KEYS.join(', ')}.
   - पानी की मोटर / टंकी की मोटर / पंप / मोटर with पानी -> water_pump
   - सबमर्सिबल / बोरिंग / बोर की मोटर -> submersible
   - पंखा / फैन -> fan; एसी -> ac; कूलर -> cooler; कटर / घास काटने की मशीन -> cutter
   - मिक्सी / ग्राइंडर / मिक्सर -> mixer; इंडक्शन / चूल्हा -> induction; हीटर / गीजर -> heater; केतली -> kettle; प्रेस / आयरन -> iron
   - anything else, or if no machine is named -> other
8. The examples below only show the format. Never copy words, names or amounts from them into your answer; use only what is in the new input.
9. Keep English technical words as they are written in the text (वाइंडिंग, कैपेसिटर). Do not translate to English. Keep each text field short, one phrase.

Examples (intake):
Input: "रामेश्वर महतो, पिठोरिया से, सबमर्सिबल मोटर नहीं चल रहा, वाइंडिंग जल गई है, पंद्रह सौ लगेगा, परसों ले जाना"
Output: {"name":"रामेश्वर महतो","village":"पिठोरिया","appliance":"submersible","complaint":"मोटर नहीं चल रहा","diagnosis":"वाइंडिंग जल गई है","work_done":null,"estimate":1500,"final_amount":null,"pickup":{"said":"परसों","days_from_today":2,"weekday":null,"day_of_month":null}}
Input: "पंखा धीरे चलता है, कैपेसिटर बदलना पड़ेगा, साढ़े तीन सौ, कल शाम तक"
Output: {"name":null,"village":null,"appliance":"fan","complaint":"धीरे चलता है","diagnosis":"कैपेसिटर बदलना पड़ेगा","work_done":null,"estimate":350,"final_amount":null,"pickup":{"said":"कल शाम तक","days_from_today":1,"weekday":null,"day_of_month":null}}
Example (quick):
Input: "मिक्सी का स्विच बदल दिया, डेढ़ सौ रुपये"
Output: {"name":null,"village":null,"appliance":"mixer","complaint":null,"diagnosis":null,"work_done":"स्विच बदला","estimate":null,"final_amount":150,"pickup":{"said":null,"days_from_today":null,"weekday":null,"day_of_month":null}}`;
}

export function intakeUserPrompt(text, kind) {
  return `Job kind: ${kind}\nWhat the electrician said:\n${text}`;
}
