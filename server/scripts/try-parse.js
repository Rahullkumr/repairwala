// Runs the intake prompt on sample Hindi lines against the real local Ollama and prints the result.
// Run: node scripts/try-parse.js   (Ollama must be up)
import { parseIntake } from '../src/services/intake.js';
import { todayString } from '../src/lib/dates.js';

const samples = [
  // The first three are the owner's own examples; the first two use Whisper's real spelling.
  ['intake', 'रामेश्वर महतो, पिठोरिया से, सबमर्सिबल मोटर नहीं चल रहा, वाइंडिंग जल गई है, पंदरह सौ लगेगा, परसों ले जाना.'],
  ['intake', 'पंखा धीरे चलता है, कैपिसिटर बदलना पड़ेगा, साढ़े तीन सौ रुपए, कल शाम तक ले जाना.'],
  ['quick', 'मिक्सी का स्विच बदल दिया, डेढ़ सौ रुपये'],
  // No amount, no name.
  ['intake', 'कूलर की मोटर जाम हो गई है, खोलकर देखना पड़ेगा'],
  // Weekday word.
  ['intake', 'सुनीता देवी, मकहर गाँव, पानी की टंकी वाली मोटर चालू नहीं हो रही, बेयरिंग खराब है, आठ सौ रुपये, बुधवार को ले जाना'],
  // Devanagari digits.
  ['intake', 'प्रेस गरम नहीं होती, एलिमेंट बदलना है, ३५० रुपये लगेंगे, आज शाम तक'],
  // Quick, with a name, bigger amount in thousands.
  ['quick', 'मोहन यादव, हीटर की रॉड बदली और तार जोड़ा, दो सौ पचास रुपये'],
  // Day of month.
  ['intake', 'कटर मशीन का कार्बन ब्रश घिस गया है, ढाई सौ लगेगा, 25 तारीख को आना'],
  // Weekday with "तक", two problems in one line.
  ['intake', 'हीटर की रॉड जल गई है, इंडक्शन का कॉइल भी देखना है, बारह सौ, शुक्रवार तक'],
];

console.log(`today (Asia/Kolkata): ${todayString()}\n`);
for (const [kind, text] of samples) {
  try {
    const out = await parseIntake(text, kind);
    console.log(`[${kind}] ${text}\n${JSON.stringify(out, null, 1).replace(/\n\s*/g, ' ')}\n`);
  } catch (err) {
    console.log(`[${kind}] ${text}\nERROR ${err.message}\n`);
  }
}
