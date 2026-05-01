const express = require('express');
const { db }   = require('../db/connection');
const restic   = require('../services/resticService');
const { requireAuth } = require('../utils/auth');

const router = express.Router();
router.use(requireAuth);

// GET  /api/restic/config/:clienteId
router.get('/config/:clienteId', async (req, res, next) => {
  try {
    const cfg = await db('restic_configs').where({ cliente_id: req.params.clienteId }).first();
    if (!cfg) return res.status(404).json({ error: 'Config non trovata' });
    // Non esporre secret key
    const { s3_secret_key, repo_password, ...safe } = cfg;
    res.json({ ...safe, s3_secret_key: '***', repo_password: '***' });
  } catch (e) { next(e); }
});

// POST /api/restic/config/:clienteId — crea / aggiorna config
router.post('/config/:clienteId', async (req, res, next) => {
  try {
    const existing = await db('restic_configs').where({ cliente_id: req.params.clienteId }).first();
    const data = { ...req.body, cliente_id: req.params.clienteId, updated_at: new Date() };
    if (existing) {
      await db('restic_configs').where({ cliente_id: req.params.clienteId }).update(data);
    } else {
      await db('restic_configs').insert({ ...data, created_at: new Date() });
    }
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// POST /api/restic/:clienteId/init
router.post('/:clienteId/init', async (req, res, next) => {
  try {
    const result = await restic.initRepo(req.params.clienteId);
    res.json({ ok: true, output: result.stdout });
  } catch (e) { next(e); }
});

// GET  /api/restic/:clienteId/snapshots
router.get('/:clienteId/snapshots', async (req, res, next) => {
  try {
    const snaps = await restic.snapshots(req.params.clienteId, {
      deviceId: req.query.device_id,
      limit:    req.query.limit,
    });
    res.json(snaps);
  } catch (e) { next(e); }
});

// POST /api/restic/:clienteId/backup — avvia backup manuale
router.post('/:clienteId/backup', async (req, res, next) => {
  try {
    const { device_id, paths, tags } = req.body;
    if (!paths?.length) return res.status(400).json({ error: 'paths richiesto' });
    const result = await restic.backup(req.params.clienteId, device_id, paths, tags);
    res.json(result);
  } catch (e) { next(e); }
});

// POST /api/restic/:clienteId/forget — applica retention policy
router.post('/:clienteId/forget', async (req, res, next) => {
  try {
    const result = await restic.forget(req.params.clienteId);
    res.json(result);
  } catch (e) { next(e); }
});

// GET  /api/restic/:clienteId/stats
router.get('/:clienteId/stats', async (req, res, next) => {
  try {
    res.json(await restic.stats(req.params.clienteId));
  } catch (e) { next(e); }
});

// POST /api/restic/:clienteId/check
router.post('/:clienteId/check', async (req, res, next) => {
  try {
    const result = await restic.check(req.params.clienteId);
    res.json({ ok: true, output: result.stdout });
  } catch (e) { next(e); }
});

module.exports = router;
