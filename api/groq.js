// Vercel serverless proxy for the Groq API.
// Flutter web calls /api/groq (same origin — no CORS).
//
// Groq retires model ids regularly. A hardcoded fallback list rots silently:
// once every id on it is decommissioned the proxy returns "All Groq models
// failed" forever, which looks identical to a missing key. So it asks Groq
// which models actually exist and picks from those.

// Preference order among whatever Groq currently offers. Matched as
// substrings so a version bump (…-70b-versatile → …-70b-versatile-v2) still
// matches without a code change.
const PREFERRED = [
  // Big Llamas first if this account ever gets them back.
  'llama-3.3-70b',
  'llama-3.1-70b',
  'llama3-70b',
  // What this account actually offers today, best first.
  'gpt-oss-120b',
  'gpt-oss-20b',
  'kimi',
  'qwen',
  'llama-3.1-8b',
  'gemma2-9b',
];

// Groq keys have been set under several names in this project over time, and
// an old dead one sitting in GROQ_KEY silently shadowed a fresh key added as
// `groq`. Rather than depend on getting the name exactly right, collect every
// candidate and use whichever one actually authenticates.
function candidateKeys() {
  const named = [
    process.env.GROQ_KEY,
    process.env.GROQ_API_KEY,
    process.env.groq,
    process.env.GROQ,
  ];
  const seen = new Set();
  const keys = [];
  for (const raw of named) {
    // A key pasted with surrounding quotes or a trailing newline fails auth
    // in a way that looks identical to a wrong key.
    const key = (raw || '').trim().replace(/^["']|["']$/g, '');
    if (key && !seen.has(key)) {
      seen.add(key);
      keys.push(key);
    }
  }
  return keys;
}

// Cached for the life of this lambda instance so most requests skip the
// extra round trip.
let cachedModels = null;
let cachedKey = null;
let cachedAt = 0;
const CACHE_MS = 10 * 60 * 1000;

/// Returns { key, ids } for the first key Groq accepts.
async function resolveGroq(keys) {
  if (cachedModels && cachedKey && Date.now() - cachedAt < CACHE_MS) {
    return { key: cachedKey, ids: cachedModels };
  }

  const problems = [];
  for (const key of keys) {
    const res = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { Authorization: `Bearer ${key}` },
    });
    if (!res.ok) {
      const detail = await res.text();
      problems.push(`${res.status}: ${detail.slice(0, 120)}`);
      continue;
    }

    const data = await res.json();
    const ids = (data.data || [])
      .map((m) => m.id)
      .filter((id) => typeof id === 'string');

    cachedModels = ids;
    cachedKey = key;
    cachedAt = Date.now();
    return { key, ids };
  }

  throw new Error(`no working key (tried ${keys.length}): ${problems.join(' | ')}`);
}

/// Preferred models that Groq actually has, best first, then anything else
/// that looks like a chat model.
function rank(ids) {
  const ranked = [];
  for (const wanted of PREFERRED) {
    for (const id of ids) {
      if (id.includes(wanted) && !ranked.includes(id)) ranked.push(id);
    }
  }
  for (const id of ids) {
    // Anything that is not a general chat model. Speech and safety models
    // return 200 with nothing usable, which reads as a working tier giving
    // empty answers — orpheus (text-to-speech) was ranked third before this.
    if (/whisper|tts|text-to-speech|orpheus|playai|sonic|speech|audio|guard|embed|rerank|moderation/i
        .test(id)) {
      continue;
    }
    if (!ranked.includes(id)) ranked.push(id);
  }
  return ranked;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const keys = candidateKeys();
  // Say which problem it is. "All Groq models failed" was returned for a
  // missing key and for retired models alike, so neither could be diagnosed.
  if (keys.length === 0) {
    return res.status(500).json({
      error: 'GROQ key not configured',
      hint: 'Set GROQ_KEY in the Vercel project environment, then redeploy.',
    });
  }

  let bodyObj;
  try {
    if (req.body && typeof req.body === 'object') {
      bodyObj = req.body;
    } else if (typeof req.body === 'string') {
      bodyObj = JSON.parse(req.body);
    } else {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      bodyObj = JSON.parse(Buffer.concat(chunks).toString('utf-8'));
    }
  } catch (e) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  let candidates;
  let groqKey;
  try {
    const resolved = await resolveGroq(keys);
    groqKey = resolved.key;
    candidates = rank(resolved.ids);
  } catch (err) {
    console.error('[groq-proxy] could not list models:', err.message);
    return res.status(502).json({ error: 'Groq unreachable', detail: err.message });
  }

  if (candidates.length === 0) {
    return res.status(502).json({ error: 'Groq offers no usable chat model' });
  }

  // Honour the requested model when Groq still has it.
  const requested = bodyObj.model;
  if (requested && candidates.includes(requested)) {
    candidates = [requested, ...candidates.filter((m) => m !== requested)];
  }

  let lastDetail = null;
  for (const model of candidates.slice(0, 4)) {
    try {
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${groqKey}`,
        },
        body: JSON.stringify({ ...bodyObj, model }),
      });

      const data = await response.json();
      if (response.ok) {
        console.log('[groq-proxy] ok, model:', model);
        return res.status(200).json(data);
      }
      lastDetail = data?.error?.message || `status ${response.status}`;
      console.error('[groq-proxy]', model, response.status, String(lastDetail).slice(0, 200));
    } catch (err) {
      lastDetail = err.message;
      console.error('[groq-proxy] fetch error', model, err.message);
    }
  }

  return res.status(502).json({
    error: 'All Groq models failed',
    tried: candidates.slice(0, 4),
    detail: lastDetail,
  });
}
