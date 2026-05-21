// Vercel serverless proxy for Groq API.
// Flutter web calls /api/groq (same origin — no CORS). Tries models in
// order until one succeeds, because some Groq model IDs rotate.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const groqKey =
    process.env.GROQ_KEY ||
    process.env.GROQ_API_KEY;

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

  const modelFallbacks = [
    'llama-3.3-70b-versatile',
    'llama3-70b-8192',
    'llama-3.1-70b-versatile',
    'mixtral-8x7b-32768',
  ];

  const requestedModel = bodyObj.model || modelFallbacks[0];
  const models = [requestedModel, ...modelFallbacks.filter(m => m !== requestedModel)];

  for (const model of models) {
    try {
      const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${groqKey}`,
        },
        body: JSON.stringify({ ...bodyObj, model }),
      });

      const data = await response.json();
      if (response.ok) {
        console.log('[groq-proxy] ok, model:', model);
        return res.status(200).json(data);
      }
      console.error('[groq-proxy] error with', model, response.status, JSON.stringify(data).slice(0, 200));
    } catch (err) {
      console.error('[groq-proxy] fetch error with', model, err.message);
    }
  }

  return res.status(502).json({ error: 'All Groq models failed' });
}
