// ============ routes/cassette.js ============
const express = require('express');
const { db }  = require('../db/connection');
const { requireAuth } = require('../utils/auth');
const r = express.Router();
r.use(requireAuth);
r.get('/', async (req, res, next) => {
  try {
    const q = db('cassette as c').leftJoin('clienti as cl','c.cliente_id','cl.id')
      .leftJoin('dispositivi as d','c.dispositivo_id','d.id')
      .select('c.*','cl.ragione_sociale','d.nome as dispositivo_nome');
    if (req.query.cliente_id) q.where('c.cliente_id', req.query.cliente_id);
    if (req.query.posizione)  q.where('c.posizione', req.query.posizione);
    res.json(await q.orderBy('cl.ragione_sociale'));
  } catch(e){next(e);}
});
r.get('/:id', async (req, res, next) => {
  try { const c = await db('cassette').where({id:req.params.id}).first(); if(!c) return res.status(404).json({error:'Non trovata'}); res.json(c); } catch(e){next(e);}
});
r.post('/', async (req, res, next) => {
  try { const [row] = await db('cassette').insert({...req.body,created_at:new Date(),updated_at:new Date()}).returning('id'); res.status(201).json({id:row.id||row}); } catch(e){next(e);}
});
r.patch('/:id', async (req, res, next) => {
  try { await db('cassette').where({id:req.params.id}).update({...req.body,updated_at:new Date()}); res.json({ok:true}); } catch(e){next(e);}
});
module.exports = r;
