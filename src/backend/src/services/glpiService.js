/**
 * GlpiService
 * Integrazione con GLPI tramite REST API.
 * Documentazione: https://github.com/glpi-project/glpi/blob/main/apirest.md
 *
 * Flussi gestiti:
 *   - Lettura computer (dispositivi cliente) → sinc anagrafica TapeGuard
 *   - Lettura entity (clienti) → sinc anagrafica clienti
 *   - Apertura ticket per rotazione/alert scaduto
 *   - Aggiornamento custom fields backup su computer GLPI
 */

const axios  = require('axios');
const { db } = require('../db/connection');
const logger = require('../utils/logger');

const BASE = process.env.GLPI_URL?.replace(/\/$/, '');
const APP_TOKEN  = process.env.GLPI_APP_TOKEN;
const USER_TOKEN = process.env.GLPI_USER_TOKEN;

// -------------------------------------------------------------------
// Session management
// -------------------------------------------------------------------
let _sessionToken = null;

async function getSession() {
  if (_sessionToken) return _sessionToken;

  const res = await axios.get(`${BASE}/apirest.php/initSession`, {
    headers: {
      'App-Token':         APP_TOKEN,
      'Authorization':     `user_token ${USER_TOKEN}`,
    },
  });
  _sessionToken = res.data.session_token;
  return _sessionToken;
}

function headers() {
  return {
    'App-Token':     APP_TOKEN,
    'Session-Token': _sessionToken,
    'Content-Type':  'application/json',
  };
}

async function glpiGet(path, params = {}) {
  await getSession();
  const res = await axios.get(`${BASE}/apirest.php/${path}`, { headers: headers(), params });
  return res.data;
}

async function glpiPost(path, data) {
  await getSession();
  const res = await axios.post(`${BASE}/apirest.php/${path}`, { input: data }, { headers: headers() });
  return res.data;
}

async function glpiPatch(path, data) {
  await getSession();
  const res = await axios.patch(`${BASE}/apirest.php/${path}`, { input: data }, { headers: headers() });
  return res.data;
}

// -------------------------------------------------------------------
// Recupera lista computer da GLPI (filtra per entity se fornito)
// -------------------------------------------------------------------
async function getComputers(glpiEntityId = null) {
  const params = { range: '0-1000', expand_dropdowns: true };
  if (glpiEntityId) params.entities_id = glpiEntityId;
  return glpiGet('Computer', params);
}

// -------------------------------------------------------------------
// Recupera lista entity (= clienti in GLPI)
// -------------------------------------------------------------------
async function getEntities() {
  return glpiGet('Entity', { range: '0-500' });
}

// -------------------------------------------------------------------
// Sincronizza computer GLPI → dispositivi_cliente TapeGuard
// Per ogni computer nell'entity del cliente, crea o aggiorna il record
// -------------------------------------------------------------------
async function syncComputersForCliente(clienteId) {
  const cliente = await db('clienti').where({ id: clienteId }).first();
  if (!cliente?.glpi_entity_id) {
    logger.warn(`Cliente ${clienteId}: glpi_entity_id non impostato, sync saltato`);
    return [];
  }

  const computers = await getComputers(cliente.glpi_entity_id);
  const synced = [];

  for (const c of computers) {
    const existing = await db('dispositivi_cliente')
      .where({ cliente_id: clienteId, glpi_computer_id: String(c.id) })
      .first();

    const data = {
      cliente_id:       clienteId,
      nome:             c.name,
      hostname:         c.name,
      ip_address:       c.last_boot || null,
      sistema_operativo: c.operatingsystems_id || null,
      tipo_device:      'SERVER',
      glpi_computer_id: String(c.id),
      attivo:           true,
      updated_at:       new Date(),
    };

    if (existing) {
      await db('dispositivi_cliente').where({ id: existing.id }).update(data);
      synced.push({ action: 'updated', id: existing.id, name: c.name });
    } else {
      const [id] = await db('dispositivi_cliente').insert({ ...data, created_at: new Date() }).returning('id');
      synced.push({ action: 'created', id: id.id || id, name: c.name });
    }
  }

  await db('clienti').where({ id: clienteId }).update({ glpi_last_sync: new Date() });

  await db('glpi_sync_log').insert({
    cliente_id:  clienteId,
    entity_type: 'COMPUTER',
    stato:       'OK',
    payload:     JSON.stringify({ count: synced.length }),
    created_at:  new Date(),
    updated_at:  new Date(),
  });

  logger.info(`GLPI sync cliente ${clienteId}: ${synced.length} computer`);
  return synced;
}

// -------------------------------------------------------------------
// Sincronizza entity GLPI → clienti TapeGuard
// -------------------------------------------------------------------
async function syncEntities() {
  const entities = await getEntities();
  const results  = [];

  for (const e of entities) {
    const existing = await db('clienti').where({ glpi_entity_id: String(e.id) }).first();
    if (existing) {
      results.push({ action: 'exists', id: existing.id, glpi_id: e.id, name: e.name });
    } else {
      results.push({ action: 'not_linked', glpi_id: e.id, name: e.name });
    }
  }

  return results;
}

// -------------------------------------------------------------------
// Apre un ticket GLPI per segnalare rotazione scaduta o alert
// -------------------------------------------------------------------
async function apriTicket({ clienteId, titolo, descrizione, urgency = 3 }) {
  const cliente = await db('clienti').where({ id: clienteId }).first();
  const entityId = cliente?.glpi_entity_id ? Number(cliente.glpi_entity_id) : 1;

  const ticket = await glpiPost('Ticket', {
    name:        titolo,
    content:     descrizione,
    entities_id: entityId,
    urgency,              // 1=very low, 3=medium, 5=very high
    type:        1,       // 1=Incident, 2=Request
    status:      1,       // 1=New
  });

  await db('glpi_sync_log').insert({
    cliente_id:  clienteId,
    entity_type: 'TICKET',
    stato:       'OK',
    payload:     JSON.stringify({ ticket_id: ticket.id, titolo }),
    created_at:  new Date(),
    updated_at:  new Date(),
  });

  logger.info(`GLPI ticket aperto: #${ticket.id} per cliente ${clienteId}`);
  return ticket;
}

// -------------------------------------------------------------------
// Aggiorna stato backup su un computer GLPI (custom field)
// -------------------------------------------------------------------
async function aggiornaStatoBackup(glpiComputerId, { ultimo_backup, stato_backup }) {
  return glpiPatch(`Computer/${glpiComputerId}`, {
    comment: `TapeGuard — Ultimo backup: ${ultimo_backup} | Stato: ${stato_backup}`,
  });
}

module.exports = {
  getComputers,
  getEntities,
  syncComputersForCliente,
  syncEntities,
  apriTicket,
  aggiornaStatoBackup,
};
