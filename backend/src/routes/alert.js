// ============ alert.js ============
const express  = require('express');
const { db }   = require('../db/connection');
const { inviaAlert } = require('../services/alertService');
const { runAlertJob } = require('../scheduler');
const { requireAuth } = require('../utils/auth');
const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    res.json(await db('alert_log as a').leftJoin('clienti as c','a.cliente_id','c.id')
      .select('a.*','c.ragione_sociale').orderBy('a.created_at','desc').limit(200));
  } catch(e){next(e);}
});
router.post('/invia/:clienteId', async (req, res, next) => {
  try {
    const c = await db('clienti').where({id:req.params.clienteId}).first();
    if(!c) return res.status(404).json({error:'Non trovato'});
    await inviaAlert(c, req.body.tipo||'scadenza');
    res.json({ok:true});
  } catch(e){next(e);}
});
router.post('/run-job', async (req, res, next) => {
  try { await runAlertJob(); res.json({ok:true}); } catch(e){next(e);}
});
router.post('/push-subscribe', async (req, res, next) => {
  try {
    const {endpoint,keys} = req.body;
    await db('push_subscriptions').insert({utente_id:req.user?.id,endpoint,p256dh:keys.p256dh,auth:keys.auth,created_at:new Date(),updated_at:new Date()}).onConflict('endpoint').merge();
    res.json({ok:true});
  } catch(e){next(e);}
});
module.exports = router;
