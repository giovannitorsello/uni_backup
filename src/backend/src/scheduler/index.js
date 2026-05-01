const cron   = require('node-cron');
const logger = require('./utils/logger');
const { getClientiInScadenza, getClientiScaduti } = require('./services/rotazioneService');
const { inviaAlert } = require('./services/alertService');

const GIORNI = Number(process.env.ALERT_DAYS_BEFORE) || 3;
const CRON   = process.env.ALERT_CRON || '0 7 * * *';

async function runAlertJob() {
  logger.info('Scheduler: controllo scadenze');
  try {
    const scaduti   = await getClientiScaduti();
    const inScadenza = await getClientiInScadenza(GIORNI);
    const scadutiIds = new Set(scaduti.map(c => c.id));

    for (const c of scaduti) {
      logger.warn(`SCADUTO: ${c.ragione_sociale}`);
      await inviaAlert(c, 'scaduto');

      // Apri ticket GLPI se configurato e cliente ha glpi_entity_id
      if (process.env.GLPI_URL && c.glpi_entity_id) {
        try {
          const glpi = require('./services/glpiService');
          await glpi.apriTicket({
            clienteId:   c.id,
            titolo:      `[TapeGuard] Rotazione nastri scaduta — ${c.ragione_sociale}`,
            descrizione: `La rotazione nastri per il cliente ${c.ragione_sociale} è scaduta il ${new Date(c.prossima_rotazione).toLocaleDateString('it-IT')}. Pianificare il ritiro immediato.`,
            urgency:     5,
          });
        } catch (err) {
          logger.error(`GLPI ticket fallito per ${c.ragione_sociale}:`, err.message);
        }
      }
    }

    for (const c of inScadenza.filter(c => !scadutiIds.has(c.id))) {
      await inviaAlert(c, 'scadenza');
    }

    logger.info(`Scheduler: ${scaduti.length} scaduti, ${inScadenza.length - scadutiIds.size} in scadenza`);
  } catch (err) {
    logger.error('Scheduler errore:', err.message);
  }
}

function start() {
  if (!cron.validate(CRON)) { logger.error(`ALERT_CRON non valido: "${CRON}"`); return; }
  cron.schedule(CRON, runAlertJob, { timezone: 'Europe/Rome' });
  logger.info(`Scheduler avviato — cron: "${CRON}", soglia: ${GIORNI}gg`);
}

module.exports = { start, runAlertJob };
