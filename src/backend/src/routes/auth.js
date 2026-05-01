// ============ routes/auth.js ============
const express = require('express');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const { db }  = require('../db/connection');
const router  = express.Router();

router.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'Credenziali mancanti' });
    const u = await db('utenti').where({ username, attivo: true }).first();
    if (!u || !(await bcrypt.compare(password, u.password_hash))) return res.status(401).json({ error: 'Credenziali non valide' });
    const token = jwt.sign({ id: u.id, username: u.username, ruolo: u.ruolo }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '8h' });
    res.json({ token, utente: { id: u.id, username: u.username, ruolo: u.ruolo } });
  } catch (e) { next(e); }
});

router.get('/me', require('../utils/auth').requireAuth, (req, res) => res.json(req.user));
module.exports = router;
