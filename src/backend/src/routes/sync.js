const express = require('express');
const { db }  = require('../db/connection');
const crm     = require('../services/crmSyncService');
const glpi    = require('../services/glpiService');
const { requireAuth } = require('../utils/auth');

const router = express.Router();

// ---------------------------------------------------------------
// CRM
// ---------------------------------------------------------------

// Webhook dal CRM (NO auth — verificata via HMAC)
router.post('/crm/webhook', async (req, res, next) => {
  try {
    const event     = req.headers['x-crm-event'] || req.body.event;
    const signature = req.headers['x-crm-signature'];
    await crm.handleWebhook(event, req.body, signature);
    res.json({ ok: true });
  } catch (e) {
    if (e.status === 401) return res.status(401).json({ error: e.message });
    next(e);
  }
});

// Tutte le route seguenti richiedono autenticazione
router.use(requireAuth);

// Pull manuale: CRM → TapeGuard
router.post('/crm/pull', async (req, res, next) => {
  try { res.json(await crm.pullFromCrm()); }
  catch (e) { next(e); }
});

// Push singolo cliente: TapeGuard → CRM
router.post('/crm/push/:clienteId', async (req, res, next) => {
  try {
    await crm.pushToCrm(req.params.clienteId);
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// Log sync CRM
router.get('/crm/log', async (req, res, next) => {
  try {
    const log = await db('crm_sync_log as l')
      .leftJoin('clienti as c', 'l.cliente_id', 'c.id')
      .select('l.*', 'c.ragione_sociale')
      .orderBy('l.created_at', 'desc')
      .limit(200);
    res.json(log);
  } catch (e) { next(e); }
});

// ---------------------------------------------------------------
// GLPI
// ---------------------------------------------------------------

// Lista entity GLPI
router.get('/glpi/entities', async (req, res, next) => {
  try { res.json(await glpi.getEntities()); }
  catch (e) { next(e); }
});

// Sync computer GLPI → dispositivi_cliente per un cliente
router.post('/glpi/sync-computers/:clienteId', async (req, res, next) => {
  try { res.json(await glpi.syncComputersForCliente(req.params.clienteId)); }
  catch (e) { next(e); }
});

// Sync entity GLPI → verifica collegamento clienti
router.get('/glpi/sync-entities', async (req, res, next) => {
  try { res.json(await glpi.syncEntities()); }
  catch (e) { next(e); }
});

// Apri ticket GLPI per rotazione scaduta
router.post('/glpi/ticket', async (req, res, next) => {
  try {
    const { clienteId, titolo, descrizione, urgency } = req.body;
    res.json(await glpi.apriTicket({ clienteId, titolo, descrizione, urgency }));
  } catch (e) { next(e); }
});

// Log sync GLPI
router.get('/glpi/log', async (req, res, next) => {
  try {
    const log = await db('glpi_sync_log as l')
      .leftJoin('clienti as c', 'l.cliente_id', 'c.id')
      .select('l.*', 'c.ragione_sociale')
      .orderBy('l.created_at', 'desc')
      .limit(200);
    res.json(log);
  } catch (e) { next(e); }
});

module.exports = router;
