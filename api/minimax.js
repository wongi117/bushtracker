// Vercel serverless proxy for MiniMax AI API.
// Flutter web calls /api/minimax (same origin — no CORS).
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const minimaxKey = process.env.MINIMAX_KEY;

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

  try {
    const response = await fetch('https://api.minimax.io/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${minimaxKey}`,
      },
      body: JSON.stringify(bodyObj),
    });

    const responseText = await response.text();
    let data;
    try { data = JSON.parse(responseText); } catch (_) { data = { raw: responseText }; }

    if (response.ok) {
      console.log('[minimax-proxy] ok, model:', data.model);
    } else {
      console.error('[minimax-proxy] STATUS:', response.status);
      console.error('[minimax-proxy] ERROR:', data?.error?.message || responseText.slice(0, 200));
    }

    return res.status(response.status).json(data);
  } catch (error) {
    console.error('[minimax-proxy] fatal:', error.message);
    return res.status(500).json({ error: error.message });
  }
}
