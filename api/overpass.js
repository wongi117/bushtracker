// Vercel serverless proxy for Overpass API (OpenStreetMap POI queries).
// Overpass blocks CORS on browsers; this runs server-side.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  let body;
  try {
    if (typeof req.body === 'string' && req.body.length > 0) {
      body = req.body;
    } else if (req.body && typeof req.body === 'object' && req.body.query) {
      body = req.body.query;
    } else {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      body = Buffer.concat(chunks).toString('utf-8');
    }
  } catch (e) {
    return res.status(400).json({ error: 'Could not read request body' });
  }

  if (!body) return res.status(400).json({ error: 'Empty Overpass query' });

  try {
    const response = await fetch('https://overpass-api.de/api/interpreter', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'BushTrack/3.0 (wanmallah1.ds@gmail.com)',
      },
      body: `data=${encodeURIComponent(body)}`,
    });

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Overpass error' });
    }

    const data = await response.json();
    res.setHeader('Cache-Control', 's-maxage=120, stale-while-revalidate');
    return res.status(200).json(data);
  } catch (err) {
    console.error('[overpass-proxy] error:', err.message);
    return res.status(502).json({ error: 'Upstream fetch failed' });
  }
}
