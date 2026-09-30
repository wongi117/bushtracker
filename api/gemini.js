// Vercel serverless proxy for Google Gemini.
//
// Flutter web used to call generativelanguage.googleapis.com directly with
// ?key=<GEMINI_KEY> built into the URL. That key was compiled into
// main.dart.js and visible in the browser's network log, so anyone opening
// the site could take it. The key now stays on the server.
//
// Model comes from ?model=, with fallbacks, because Google withdraws dated
// preview model ids once the stable release lands.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const key = process.env.GEMINI_API_KEY || process.env.GEMINI_KEY;
  if (!key) return res.status(500).json({ error: 'GEMINI key not configured' });

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
    return res.status(400).json({ error: 'Invalid JSON body', detail: e.message });
  }

  const requested = (req.query && req.query.model) || 'gemini-2.5-flash';
  const fallbacks = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest'];
  const models = [requested, ...fallbacks.filter((m) => m !== requested)];

  let lastDetail = null;
  for (const model of models) {
    try {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}` +
        `:generateContent?key=${encodeURIComponent(key)}`;

      const upstream = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyObj),
      });

      const data = await upstream.json();
      if (upstream.ok) {
        console.log('[gemini-proxy] ok, model:', model);
        return res.status(200).json(data);
      }
      lastDetail = data;
      console.error('[gemini-proxy]', model, upstream.status,
        JSON.stringify(data).slice(0, 200));
    } catch (err) {
      lastDetail = { message: err.message };
      console.error('[gemini-proxy] fetch error', model, err.message);
    }
  }

  return res.status(502).json({ error: 'All Gemini models failed', detail: lastDetail });
}
