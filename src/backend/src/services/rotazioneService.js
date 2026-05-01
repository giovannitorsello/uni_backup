// ============================================================
// rotazioneService.js
// ============================================================
const { db } = require('../db/connection');
const logger = require('./logger');

const CICLO = [
  { da: 'TERZO',     a: 'FORNITORE', delta_t:  0 },
  { da: 'SEDE',      a: 'TERZO',     delta_t: -2 },
  { da: 'FORNITORE', a: 'SEDE',      delta_t: -1 },
];

async function eseguiRotazione(clienteId, operatore = 'sistema') {
  const cassette = await db('cassette').where({ cliente_id: clienteId });
  if (cassette.length !== 3) throw new Error(`Attese 3 cassette, trovate ${cassette.length}`);
  const byPos = Object.fromEntries(cassette.map(c => [c.posizione, c]));
  const movimenti = [];
  await db.transaction(async trx => {
    for (const step of CICLO) {
      const c = byPos[step.da];
      if (!c) throw new Error(`Cassetta ${step.da} non trovata`);
      await trx('cassette').where({ id: c.id }).update({ posizione: step.a, delta_t: step.delta_t, updated_at: new Date() });
      await trx('rotazioni').insert({ cliente_id: clienteId, cassetta_id: c.id, posizione_da: step.da, posizione_a: step.a, operatore, created_at: new Date(), updated_at: new Date() });
      movimenti.push({ label: c.label_bareos, da: step.da, a: step.a });
    }
    const cliente = await trx('clienti').where({ id: clienteId }).first();
    const prossima = new Date(); prossima.setDate(prossima.getDate() + cliente.periodo_giorni);
    await trx('clienti').where({ id: clienteId }).update({ ultima_rotazione: new Date(), prossima_rotazione: prossima, updated_at: new Date() });
  });
  logger.info(`Rotazione cliente ${clienteId}:`, movimenti);
  return movimenti;
}

async function getClientiInScadenza(giorni) {
  const soglia = new Date(); soglia.setDate(soglia.getDate() + giorni);
  return db('clienti').where('attivo', true).where('prossima_rotazione', '<=', soglia).orderBy('prossima_rotazione');
}

async function getClientiScaduti() {
  return db('clienti').where('attivo', true).where('prossima_rotazione', '<', new Date()).orderBy('prossima_rotazione');
}

async function ricalcolaProssimaRotazione(clienteId) {
  const c = await db('clienti').where({ id: clienteId }).first();
  if (!c.ultima_rotazione) return;
  const p = new Date(c.ultima_rotazione); p.setDate(p.getDate() + c.periodo_giorni);
  await db('clienti').where({ id: clienteId }).update({ prossima_rotazione: p, updated_at: new Date() });
}

module.exports = { eseguiRotazione, getClientiInScadenza, getClientiScaduti, ricalcolaProssimaRotazione };
