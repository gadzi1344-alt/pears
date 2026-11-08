module.exports = function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  const url = process.env.SUPABASE_URL || '';
  const key = process.env.SUPABASE_ANON_KEY || '';
  if (!url || !key) return res.status(503).json({error:'На Vercel не заданы SUPABASE_URL и SUPABASE_ANON_KEY.'});
  res.status(200).json({url, key});
};
