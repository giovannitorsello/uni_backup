// ============ rotazioni.js ============
const express = require('express');
const { db }  = require('../db/connection');
const { requireAuth } = require('../utils/auth');
const r1 = express.Router();
r1.use(requireAuth);
r1.get('/', async (req, res, next) => {
  try {
    const q = db('rotazioni as r').leftJoin('clienti as c','r.cliente_id','c.id').leftJoin('cassette as ca','r.cassetta_id','ca.id')
      .select('r.*','c.ragione_sociale','ca.label_bareos').orderBy('r.data_rotazione','desc');
    if (req.query.cliente_id) q.where('r.cliente_id', req.query.cliente_id);
    q.limit(Number(req.query.limit)||100);
    res.json(await q);
  } catch(e){next(e);}
});
module.exports = r1;
