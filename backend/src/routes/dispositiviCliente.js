const express = require('express');
const { db }  = require('../db/connection');
const bareos  = require('../services/bareosService');
const { requireAuth } = require('../utils/auth');

const router = express.Router();
router.use(requireAuth);

// GET /api/dispositivi-cliente?cliente_id=
router.get('/', async (req, res, next) => {
  try {
    const q = db('dispositivi_cliente as d')
      .leftJoin('clienti as c', 'd.cliente_id', 'c.id')
      .select('d.*', 'c.ragione_sociale')
      .where('d.attivo', true)
      .orderBy('c.ragione_sociale')
      .orderBy('d.nome');
    if (req.query.cliente_id) q.where('d.cliente_id', req.query.cliente_id);
    res.json(await q);
  } catch (e) { next(e); }
});

// GET /api/dispositivi-cliente/:id
router.get('/:id', async (req, res, next) => {
  try {
    const d = await db('dispositivi_cliente as d')
      .leftJoin('clienti as c', 'd.cliente_id', 'c.id')
      .select('d.*', 'c.ragione_sociale')
      .where('d.id', req.params.id)
      .first();
    if (!d) return res.status(404).json({ error: 'Non trovato' });
    res.json(d);
  } catch (e) { next(e); }
});

// POST /api/dispositivi-cliente
router.post('/', async (req, res, next) => {
  try {
    const [row] = await db('dispositivi_cliente')
      .insert({ ...req.body, attivo: true, created_at: new Date(), updated_at: new Date() })
      .returning('id');
    res.status(201).json({ id: row.id || row });
  } catch (e) { next(e); }
});

// PATCH /api/dispositivi-cliente/:id
router.patch('/:id', async (req, res, next) => {
  try {
    await db('dispositivi_cliente').where({ id: req.params.id })
      .update({ ...req.body, updated_at: new Date() });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// DELETE (soft) /api/dispositivi-cliente/:id
router.delete('/:id', async (req, res, next) => {
  try {
    await db('dispositivi_cliente').where({ id: req.params.id })
      .update({ attivo: false, updated_at: new Date() });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// GET /api/dispositivi-cliente/:id/bareos-status
// Interroga il Director per lo stato del FD del device
router.get('/:id/bareos-status', async (req, res, next) => {
  try {
    const d = await db('dispositivi_cliente').where({ id: req.params.id }).first();
    if (!d?.bareos_fd_name) return res.status(400).json({ error: 'bareos_fd_name non configurato' });

    const output = await bareos.statusClient(d.bareos_fd_name);
    const online = !output.toLowerCase().includes('cannot connect');

    await db('dispositivi_cliente').where({ id: req.params.id }).update({
      bareos_fd_status:    online ? 'ONLINE' : 'OFFLINE',
      bareos_fd_last_seen: online ? new Date() : undefined,
      updated_at:          new Date(),
    });

    res.json({ online, output });
  } catch (e) { next(e); }
});

module.exports = router;
