// Vercel serverless proxy for Nominatim (OpenStreetMap) search.
// Flutter Web can't set User-Agent or hit Nominatim directly due to CORS.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const { q, lat, lon } = req.query;
  if (!q) return res.status(400).json({ error: 'Missing q parameter' });

  const params = new URLSearchParams({
    q,
    format: 'json',
    limit: '15',
    addressdetails: '1',
  });
  if (lat && lon) {
    params.set('lat', lat);
    params.set('lon', lon);
  }

  try {
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?${params.toString()}`,
      {
        headers: {
          'User-Agent': 'BushTrack/3.0 (wanmallah1.ds@gmail.com)',
          'Accept': 'application/json',
        },
      }
    );

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Nominatim error' });
    }

    const data = await response.json();
    res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate');
    return res.status(200).json(data);
  } catch (err) {
    console.error('[nominatim-proxy] error:', err.message);
    return res.status(502).json({ error: 'Upstream fetch failed' });
  }
}
