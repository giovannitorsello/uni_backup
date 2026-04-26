const express = require('express');
const { db }  = require('../db/connection');
const bareos  = require('../services/bareosService');
const { requireAuth } = require('../utils/auth');
const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const list = await db('dispositivi').where({attivo:true}).orderBy('nome');
    const storage = await bareos.getStorageDaemons().catch(()=>[]);
    const byName = Object.fromEntries(storage.map(s=>[s.name,s]));
    res.json(list.map(d=>({...d, bareos_enabled: byName[d.bareos_storage_name]?.enabled ?? null})));
  } catch(e){next(e);}
});
router.post('/', async (req, res, next) => {
  try { const [row] = await db('dispositivi').insert({...req.body,attivo:true,created_at:new Date(),updated_at:new Date()}).returning('id'); res.status(201).json({id:row.id||row}); } catch(e){next(e);}
});
router.patch('/:id', async (req, res, next) => {
  try { await db('dispositivi').where({id:req.params.id}).update({...req.body,updated_at:new Date()}); res.json({ok:true}); } catch(e){next(e);}
});
router.get('/:id/status', async (req, res, next) => {
  try {
    const d = await db('dispositivi').where({id:req.params.id}).first();
    if(!d) return res.status(404).json({error:'Non trovato'});
    res.json({output: await bareos.statusStorage(d.bareos_storage_name)});
  } catch(e){next(e);}
});
module.exports = router;
