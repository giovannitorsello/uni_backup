/**
 * CrmSyncService
 * Adattatore generico per sincronizzazione CRM esterno ↔ TapeGuard.
 *
 * Approccio:
 *   - PUSH dal CRM: il CRM invia webhook su /api/sync/crm/webhook
 *   - PULL da TapeGuard: job schedulato o manuale chiama l'API CRM
 *   - PUSH da TapeGuard: aggiorna il CRM quando un cliente viene modificato
 *
 * Il mapping campi è configurabile in docker/crm/field-map.json
 * In assenza di documentazione specifica del CRM, usa il formato REST JSON
 * standard che la maggior parte dei CRM moderni espone.
 */

const axios  = require('axios');
const crypto = require('crypto');
const { db } = require('../db/connection');
const logger = require('../utils/logger');

const CRM_BASE   = process.env.CRM_API_URL?.replace(/\/$/, '');
const CRM_KEY    = process.env.CRM_API_KEY;
const HMAC_SECRET = process.env.CRM_WEBHOOK_SECRET || '';

// -------------------------------------------------------------------
// Mapping campi CRM → TapeGuard (personalizzabile)
// Struttura: { campo_tapeguard: 'campo_crm' }
// -------------------------------------------------------------------
const DEFAULT_FIELD_MAP = {
  ragione_sociale:    'name',
  partita_iva:        'vat_number',
  codice_fiscale:     'tax_code',
  indirizzo:          'billing_address',
  citta:              'billing_city',
  cap:                'billing_zip',
  provincia:          'billing_state',
  email_referente:    'contact_email',
  nome_referente:     'contact_name',
  telefono_referente: 'contact_phone',
  crm_external_id:    'id',
};

function mapFromCrm(crmRecord, fieldMap = DEFAULT_FIELD_MAP) {
  const out = {};
  for (const [tgField, crmField] of Object.entries(fieldMap)) {
    if (crmRecord[crmField] !== undefined) out[tgField] = crmRecord[crmField];
  }
  return out;
}

function mapToCrm(tgRecord, fieldMap = DEFAULT_FIELD_MAP) {
  const out = {};
  const reverseMap = Object.fromEntries(Object.entries(fieldMap).map(([k, v]) => [v, k]));
  for (const [crmField, tgField] of Object.entries(reverseMap)) {
    if (tgRecord[tgField] !== undefined) out[crmField] = tgRecord[tgField];
  }
  return out;
}

// -------------------------------------------------------------------
// Verifica firma HMAC webhook (se CRM supporta)
// -------------------------------------------------------------------
function verificaWebhookSignature(payload, signature) {
  if (!HMAC_SECRET) return true; // skip se non configurato
  const expected = crypto
    .createHmac('sha256', HMAC_SECRET)
    .update(JSON.stringify(payload))
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(signature || ''),
    Buffer.from(expected)
  );
}

// -------------------------------------------------------------------
// PULL: scarica tutti i clienti dal CRM e aggiorna TapeGuard
// -------------------------------------------------------------------
async function pullFromCrm() {
  if (!CRM_BASE) throw new Error('CRM_API_URL non configurata');

  const res = await axios.get(`${CRM_BASE}/api/contacts`, {
    headers: { Authorization: `Bearer ${CRM_KEY}` },
    params:  { type: 'company', per_page: 500 },
  });

  const crmRecords = res.data?.data || res.data || [];
  const results = { created: 0, updated: 0, errors: 0 };

  for (const crmRecord of crmRecords) {
    try {
      const mapped = mapFromCrm(crmRecord);
      if (!mapped.ragione_sociale) continue;

      const existing = await db('clienti')
        .where({ crm_external_id: String(crmRecord.id) })
        .first();

      if (existing) {
        await db('clienti').where({ id: existing.id }).update({
          ...mapped,
          crm_last_sync: new Date(),
          updated_at:    new Date(),
        });
        results.updated++;
      } else {
        await db('clienti').insert({
          ...mapped,
          crm_external_id: String(crmRecord.id),
          backup_backend:  'BAREOS',
          periodo_giorni:  7,
          attivo:          true,
          crm_last_sync:   new Date(),
          created_at:      new Date(),
          updated_at:      new Date(),
        });
        results.created++;
      }
    } catch (err) {
      logger.error(`CRM pull errore su record ${crmRecord.id}:`, err.message);
      results.errors++;
    }
  }

  await db('crm_sync_log').insert({
    direzione:  'CRM_TO_TG',
    stato:      results.errors > 0 ? 'PARZIALE' : 'OK',
    payload:    JSON.stringify(results),
    created_at: new Date(),
    updated_at: new Date(),
  });

  logger.info(`CRM pull: ${results.created} nuovi, ${results.updated} aggiornati, ${results.errors} errori`);
  return results;
}

// -------------------------------------------------------------------
// PUSH: aggiorna un cliente sul CRM
// -------------------------------------------------------------------
async function pushToCrm(clienteId) {
  if (!CRM_BASE) throw new Error('CRM_API_URL non configurata');

  const cliente = await db('clienti').where({ id: clienteId }).first();
  if (!cliente) throw new Error(`Cliente ${clienteId} non trovato`);
  if (!cliente.crm_external_id) throw new Error(`Cliente ${clienteId} non ha crm_external_id`);

  const payload = mapToCrm(cliente);

  await axios.patch(`${CRM_BASE}/api/contacts/${cliente.crm_external_id}`, payload, {
    headers: {
      Authorization: `Bearer ${CRM_KEY}`,
      'Content-Type': 'application/json',
    },
  });

  await db('clienti').where({ id: clienteId }).update({ crm_last_sync: new Date() });

  await db('crm_sync_log').insert({
    cliente_id: clienteId,
    direzione:  'TG_TO_CRM',
    stato:      'OK',
    payload:    JSON.stringify(payload),
    created_at: new Date(),
    updated_at: new Date(),
  });

  logger.info(`CRM push cliente ${clienteId} → ${cliente.crm_external_id}`);
}

// -------------------------------------------------------------------
// Gestisce un evento webhook ricevuto dal CRM
// -------------------------------------------------------------------
async function handleWebhook(event, payload, signature) {
  if (!verificaWebhookSignature(payload, signature)) {
    throw Object.assign(new Error('Firma webhook non valida'), { status: 401 });
  }

  logger.info(`CRM webhook: ${event}`, { id: payload.id });

  switch (event) {
    case 'contact.created':
    case 'contact.updated': {
      const mapped = mapFromCrm(payload);
      if (!mapped.ragione_sociale) break;

      const existing = await db('clienti')
        .where({ crm_external_id: String(payload.id) })
        .first();

      if (existing) {
        await db('clienti').where({ id: existing.id })
          .update({ ...mapped, crm_last_sync: new Date(), updated_at: new Date() });
      } else if (event === 'contact.created') {
        await db('clienti').insert({
          ...mapped,
          crm_external_id: String(payload.id),
          backup_backend:  'BAREOS',
          periodo_giorni:  7,
          attivo:          true,
          crm_last_sync:   new Date(),
          created_at:      new Date(),
          updated_at:      new Date(),
        });
      }
      break;
    }
    case 'contact.deleted': {
      await db('clienti')
        .where({ crm_external_id: String(payload.id) })
        .update({ attivo: false, updated_at: new Date() });
      break;
    }
    default:
      logger.warn(`CRM webhook: evento non gestito: ${event}`);
  }

  await db('crm_sync_log').insert({
    direzione:  'CRM_TO_TG',
    stato:      'OK',
    payload:    JSON.stringify({ event, id: payload.id }),
    created_at: new Date(),
    updated_at: new Date(),
  });
}

module.exports = { pullFromCrm, pushToCrm, handleWebhook, verificaWebhookSignature };
