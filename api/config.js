module.exports = function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  const url = process.env.SUPABASE_URL || '';
  const key = process.env.SUPABASE_ANON_KEY || '';
  if (!url || !key) return res.status(503).json({error:'На Vercel не заданы SUPABASE_URL и SUPABASE_ANON_KEY.'});
  const rawBot = process.env.PEAR_BOT_USERNAME || 'pearnumber_app';
  const botUsername = /^[A-Za-z0-9_]{5,32}$/.test(rawBot) ? rawBot : 'pearnumber_app';
  res.status(200).json({url, key, botUsername});
};
