const express = require('express');
const { db }  = require('../db/connection');
const { eseguiRotazione, ricalcolaProssimaRotazione } = require('../services/rotazioneService');
const { requireAuth } = require('../utils/auth');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const q = db('clienti').where({ attivo: true }).orderBy('ragione_sociale');
    if (req.query.backend) q.where('backup_backend', req.query.backend);
    res.json(await q);
  } catch (e) { next(e); }
});

router.get('/:id', async (req, res, next) => {
  try {
    const cliente = await db('clienti').where({ id: req.params.id }).first();
    if (!cliente) return res.status(404).json({ error: 'Non trovato' });
    const [cassette, rotazioni, dispositivi, resticCfg] = await Promise.all([
      db('cassette').where({ cliente_id: cliente.id }).orderBy('delta_t', 'desc'),
      db('rotazioni').where({ cliente_id: cliente.id }).orderBy('data_rotazione', 'desc').limit(20),
      db('dispositivi_cliente').where({ cliente_id: cliente.id, attivo: true }),
      db('restic_configs').where({ cliente_id: cliente.id }).first(),
    ]);
    const resticSafe = resticCfg ? { ...resticCfg, s3_secret_key: '***', repo_password: '***' } : null;
    res.json({ ...cliente, cassette, rotazioni, dispositivi, restic_config: resticSafe });
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const [row] = await db('clienti')
      .insert({ ...req.body, attivo: true, created_at: new Date(), updated_at: new Date() })
      .returning('id');
    res.status(201).json({ id: row.id || row });
  } catch (e) { next(e); }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { periodo_giorni, ...rest } = req.body;
    await db('clienti').where({ id: req.params.id })
      .update({ ...rest, ...(periodo_giorni ? { periodo_giorni } : {}), updated_at: new Date() });
    if (periodo_giorni) await ricalcolaProssimaRotazione(req.params.id);
    res.json({ ok: true });
  } catch (e) { next(e); }
});

router.post('/:id/rotazione', async (req, res, next) => {
  try {
    const movimenti = await eseguiRotazione(Number(req.params.id), req.user?.username || 'operatore');
    res.json({ ok: true, movimenti });
  } catch (e) { next(e); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    await db('clienti').where({ id: req.params.id }).update({ attivo: false, updated_at: new Date() });
    res.json({ ok: true });
  } catch (e) { next(e); }
});

module.exports = router;
