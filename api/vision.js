// Vercel serverless proxy for camera identification (rock / mineral / plant).
//
// Takes a base64 JPEG and a mode, asks a vision model, and returns strict
// JSON the app can render. Keys stay server-side.
//
// Tries Anthropic first (best reasoning), falls back to Gemini, so a provider
// running out of credit degrades instead of breaking the feature.

const SAFETY_RULES = `
You are identifying something for someone standing in remote Australian bush,
possibly hours from help. Accuracy and honesty matter more than being useful.

Rules you must follow:
- If you are not confident, say so. "low" confidence is a valid, useful answer.
- Never claim certainty from a photo alone. Identification from an image is
  provisional.
- NEVER tell someone a plant is safe to eat. Even for a plant you are certain
  about, the safety field must warn that field identification is not enough to
  eat something. People die from lookalikes.
- If the plant is known to be toxic, say so plainly and first.
- If the image is too blurry, too far away, or does not contain the subject,
  set name to "Unclear" and say what a better photo would need.`;

const MODE_PROMPTS = {
  rock: `Identify the rock or mineral in this photo.

${SAFETY_RULES}

Report:
- the most likely rock or mineral type
- minerals commonly associated with it
- what it suggests about the local geology
- any hazard worth knowing (asbestiform minerals, silica dust, radioactivity,
  sharp fracture, unstable face)

Set "safety" to "hazard" if there is a real handling or dust risk, otherwise
"not-applicable".`,

  plant: `Identify the plant in this photo.

${SAFETY_RULES}

Report:
- the most likely species or genus, and the common name if it has one
- how to tell it apart from things it is confused with
- traditional or practical uses, if any are well established
- its toxicity status

Set "safety" to one of: "toxic" (known poisonous), "irritant" (sap, spines,
contact reaction), "caution" (edible parts exist but preparation matters or
lookalikes are dangerous), or "unknown". Do NOT use any other value. There is
deliberately no "safe" option.`,
};

const SCHEMA = `
Reply with ONLY a JSON object, no markdown fence, in exactly this shape:
{
  "name": "most likely identification, or Unclear",
  "alsoKnownAs": "other common names, or empty string",
  "confidence": "high" | "medium" | "low",
  "summary": "two or three plain sentences a person can read at a glance",
  "safety": "toxic" | "irritant" | "caution" | "hazard" | "unknown" | "not-applicable",
  "safetyNote": "one or two sentences on the risk, or empty string",
  "notes": ["short practical point", "another"]
}`;

async function tryAnthropic(mode, image, question) {
  const key = process.env.ANTHROPIC_KEY;
  if (!key) return { error: 'no anthropic key' };

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-5',
      max_tokens: 1024,
      system: MODE_PROMPTS[mode] + SCHEMA,
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: image } },
          { type: 'text', text: question || 'Identify this.' },
        ],
      }],
    }),
  });

  const data = await res.json();
  if (!res.ok) return { error: data?.error?.message || `anthropic ${res.status}` };

  const block = (data.content || []).find((c) => c.type === 'text');
  return block ? { text: block.text, provider: 'Claude Sonnet 5' }
               : { error: 'anthropic returned no text' };
}

async function tryGemini(mode, image, question) {
  const key = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
  if (!key) return { error: 'no gemini key' };

  const url = 'https://generativelanguage.googleapis.com/v1beta/models/' +
    `gemini-2.5-flash:generateContent?key=${encodeURIComponent(key)}`;

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: MODE_PROMPTS[mode] + SCHEMA }] },
      contents: [{
        role: 'user',
        parts: [
          { inline_data: { mime_type: 'image/jpeg', data: image } },
          { text: question || 'Identify this.' },
        ],
      }],
      generationConfig: { maxOutputTokens: 1024, temperature: 0.2 },
    }),
  });

  const data = await res.json();
  if (!res.ok) return { error: data?.error?.message || `gemini ${res.status}` };

  const text = data?.candidates?.[0]?.content?.parts
    ?.map((p) => p.text).filter(Boolean).join('');
  return text ? { text, provider: 'Gemini 2.5 Flash' }
              : { error: 'gemini returned no text' };
}

/// Models sometimes wrap JSON in a markdown fence despite being told not to.
function parseResult(text) {
  const cleaned = text.trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '');
  try {
    return JSON.parse(cleaned);
  } catch (e) {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try { return JSON.parse(cleaned.slice(start, end + 1)); } catch (_) {}
    }
    return null;
  }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  let body;
  try {
    if (req.body && typeof req.body === 'object') body = req.body;
    else if (typeof req.body === 'string') body = JSON.parse(req.body);
    else {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      body = JSON.parse(Buffer.concat(chunks).toString('utf-8'));
    }
  } catch (e) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  const mode = body.mode === 'plant' ? 'plant' : 'rock';
  let image = body.image || '';
  // Accept a data: URI or bare base64.
  const comma = image.indexOf('base64,');
  if (comma >= 0) image = image.slice(comma + 7);
  if (!image) return res.status(400).json({ error: 'No image supplied' });

  // Gemini is disabled: it bills to an account that is not funded. Claude
  // handles identification. Put tryGemini back in this list to re-enable it.
  const attempts = [];
  for (const provider of [tryAnthropic]) {
    let out;
    try {
      out = await provider(mode, image, body.question);
    } catch (err) {
      out = { error: err.message };
    }
    if (out.error) {
      attempts.push(out.error);
      console.error('[vision]', out.error);
      continue;
    }
    const parsed = parseResult(out.text);
    if (!parsed) {
      attempts.push('unparseable reply');
      continue;
    }
    return res.status(200).json({ ...parsed, mode, provider: out.provider });
  }

  return res.status(502).json({ error: 'Identification unavailable', attempts });
}
