// Vercel serverless proxy for Anthropic Claude API.
// Flutter web calls /api/claude (same origin — no CORS).
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const anthropicKey = process.env.ANTHROPIC_KEY;

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

  // Log exactly what Flutter is sending so we can debug 400s
  console.log('[claude-proxy] model:', bodyObj.model);
  console.log('[claude-proxy] message_count:', bodyObj.messages?.length);
  console.log('[claude-proxy] first_msg_role:', bodyObj.messages?.[0]?.role);
  console.log('[claude-proxy] last_msg_role:', bodyObj.messages?.[bodyObj.messages?.length - 1]?.role);

  try {
    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(bodyObj),
    });

    // Read as text first so we can log the full error without truncation
    const responseText = await anthropicRes.text();
    let data;
    try {
      data = JSON.parse(responseText);
    } catch (_) {
      data = { raw: responseText };
    }

    if (!anthropicRes.ok) {
      console.error('[claude-proxy] STATUS:', anthropicRes.status);
      console.error('[claude-proxy] ERROR_TYPE:', data?.error?.type);
      console.error('[claude-proxy] ERROR_MSG:', data?.error?.message);
      console.error('[claude-proxy] FULL_BODY:', responseText);
    } else {
      console.log('[claude-proxy] ok — input:', data.usage?.input_tokens, 'output:', data.usage?.output_tokens);
    }

    return res.status(anthropicRes.status).json(data);
  } catch (error) {
    console.error('[claude-proxy] fatal:', error.message);
    return res.status(500).json({ error: error.message });
  }
}
