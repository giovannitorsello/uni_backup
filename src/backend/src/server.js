require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');

const logger     = require('./utils/logger');
const { initDb } = require('./db/connection');
const scheduler  = require('./scheduler');

// Routes
const authRoutes           = require('./routes/auth');
const clientiRoutes        = require('./routes/clienti');
const cassetteRoutes       = require('./routes/cassette');
const rotazioniRoutes      = require('./routes/rotazioni');
const dispositiviRoutes    = require('./routes/dispositivi');           // lettori nastro fornitore
const dispositiviClienteRoutes = require('./routes/dispositiviCliente'); // anagrafica device cliente
const alertRoutes          = require('./routes/alert');
const bareosRoutes         = require('./routes/bareos');
const resticRoutes         = require('./routes/restic');
const syncRoutes           = require('./routes/sync');                  // CRM + GLPI

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());
app.use(morgan('combined', { stream: { write: m => logger.info(m.trim()) } }));

// API
app.use('/api/auth',                authRoutes);
app.use('/api/clienti',             clientiRoutes);
app.use('/api/cassette',            cassetteRoutes);
app.use('/api/rotazioni',           rotazioniRoutes);
app.use('/api/dispositivi',         dispositiviRoutes);
app.use('/api/dispositivi-cliente', dispositiviClienteRoutes);
app.use('/api/alert',               alertRoutes);
app.use('/api/bareos',              bareosRoutes);
app.use('/api/restic',              resticRoutes);
app.use('/api/sync',                syncRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date() }));

app.use((err, _req, res, _next) => {
  logger.error(err.stack || err.message);
  res.status(err.status || 500).json({ error: err.message || 'Errore interno' });
});

async function start() {
  await initDb();
  scheduler.start();
  app.listen(PORT, () => logger.info(`TapeGuard API porta ${PORT}`));
}

start().catch(err => { logger.error('Avvio fallito:', err); process.exit(1); });
