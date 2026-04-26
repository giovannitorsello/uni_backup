const express = require('express');
const bareos  = require('../services/bareosService');
const { requireAuth } = require('../utils/auth');
const router = express.Router();
router.use(requireAuth);

router.get('/volumi',                async (req,res,next)=>{try{res.json(await bareos.getVolumi(req.query.pool));}catch(e){next(e);}});
router.get('/volumi/:label',         async (req,res,next)=>{try{res.json(await bareos.getVolume(req.params.label));}catch(e){next(e);}});
router.get('/pool',                  async (req,res,next)=>{try{res.json(await bareos.getPools());}catch(e){next(e);}});
router.get('/storage',               async (req,res,next)=>{try{res.json(await bareos.getStorageDaemons());}catch(e){next(e);}});
router.get('/status/director',       async (req,res,next)=>{try{res.json({output:await bareos.statusDirector()});}catch(e){next(e);}});
router.get('/status/storage/:nome',  async (req,res,next)=>{try{res.json({output:await bareos.statusStorage(req.params.nome)});}catch(e){next(e);}});
router.get('/status/client/:nome',   async (req,res,next)=>{try{res.json({output:await bareos.statusClient(req.params.nome)});}catch(e){next(e);}});
router.get('/jobs/:clientName',      async (req,res,next)=>{try{res.json(await bareos.getJobsPerClient(req.params.clientName,Number(req.query.limit)||10));}catch(e){next(e);}});
router.post('/label',                async (req,res,next)=>{try{res.json({output:await bareos.labelVolume(req.body)});}catch(e){next(e);}});
router.post('/volume-status',        async (req,res,next)=>{try{res.json({output:await bareos.updateVolumeStatus(req.body)});}catch(e){next(e);}});

module.exports = router;
