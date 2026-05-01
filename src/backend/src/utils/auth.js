const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const h = req.headers['authorization'];
  if (!h?.startsWith('Bearer ')) return res.status(401).json({ error: 'Token mancante' });
  try {
    req.user = jwt.verify(h.slice(7), process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Token non valido o scaduto' });
  }
}

function requireAdmin(req, res, next) {
  if (req.user?.ruolo !== 'ADMIN') return res.status(403).json({ error: 'Solo amministratori' });
  next();
}

module.exports = { requireAuth, requireAdmin };
