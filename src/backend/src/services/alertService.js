const nodemailer = require('nodemailer');
const webpush    = require('web-push');
const { db }     = require('../db/connection');
const logger     = require('../utils/logger');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST, port: Number(process.env.SMTP_PORT) || 587,
  secure: process.env.SMTP_PORT === '465',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

if (process.env.VAPID_PUBLIC_KEY && process.env.VAPID_PRIVATE_KEY) {
  webpush.setVapidDetails(process.env.VAPID_SUBJECT, process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
}

async function inviaEmailAlert(cliente, tipo) {
  const scaduto = tipo === 'scaduto';
  const backend = cliente.backup_backend || 'BAREOS';
  const prossima = cliente.prossima_rotazione ? new Date(cliente.prossima_rotazione).toLocaleDateString('it-IT') : 'N/D';

  const html = `
    <div style="font-family:sans-serif;max-width:600px">
      <h2 style="color:${scaduto ? '#A32D2D' : '#854F0B'}">
        ${scaduto ? 'Rotazione nastri SCADUTA' : 'Rotazione nastri in scadenza'}
      </h2>
      <table style="width:100%;border-collapse:collapse;font-size:14px">
        <tr><td style="padding:4px;color:#666">Cliente</td><td><b>${cliente.ragione_sociale}</b></td></tr>
        <tr><td style="padding:4px;color:#666">Periodo</td><td>ogni ${cliente.periodo_giorni} giorni</td></tr>
        <tr><td style="padding:4px;color:#666">Scadenza</td><td>${prossima}</td></tr>
        <tr><td style="padding:4px;color:#666">Backend backup</td><td>${backend}</td></tr>
      </table>
      <h3 style="margin-top:20px">Azioni richieste</h3>
      ${backend !== 'RESTIC_S3' ? `
      <h4>Nastro</h4>
      <ol>
        <li>Ritirare cassetta da <b>luogo terzo</b>: ${cliente.nome_luogo_terzo || 'N/D'} (${cliente.email_luogo_terzo || ''})</li>
        <li>Portare all'unità nastro per scrittura nuovo backup</li>
        <li>Consegnare cassetta SEDE → luogo terzo</li>
        <li>Registrare rotazione su TapeGuard</li>
      </ol>` : ''}
      ${backend !== 'BAREOS' ? `
      <h4>Restic / S3</h4>
      <p>Verificare l'ultimo snapshot su S3 e applicare la retention policy se necessario.</p>` : ''}
      <p style="color:#888;font-size:11px;margin-top:30px">TapeGuard — sistema gestione backup</p>
    </div>`;

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to:   cliente.email_referente,
    subject: `[TapeGuard] ${scaduto ? 'URGENTE - ' : ''}Rotazione nastri ${scaduto ? 'scaduta' : 'in scadenza'} — ${cliente.ragione_sociale}`,
    html,
  });
}

async function inviaPushAlert(cliente, tipo) {
  const subs = await db('push_subscriptions').select('*');
  if (!subs.length) return;
  const payload = JSON.stringify({
    title: tipo === 'scaduto' ? `URGENTE: ${cliente.ragione_sociale}` : `Rotazione: ${cliente.ragione_sociale}`,
    body:  tipo === 'scaduto' ? 'Rotazione scaduta. Ritiro immediato.' : `Scadenza tra ${process.env.ALERT_DAYS_BEFORE || 3} giorni.`,
    data:  { clienteId: cliente.id },
  });
  await Promise.allSettled(subs.map(s =>
    webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload)
      .catch(async err => { if (err.statusCode === 410) await db('push_subscriptions').where({ id: s.id }).delete(); })
  ));
}

async function inviaAlert(cliente, tipo = 'scadenza') {
  let stato = 'INVIATO'; let errMsg = null;
  try {
    await inviaEmailAlert(cliente, tipo);
    await inviaPushAlert(cliente, tipo);
  } catch (err) {
    stato = 'ERRORE'; errMsg = err.message;
    logger.error(`Alert errore ${cliente.ragione_sociale}:`, err.message);
  }
  await db('alert_log').insert({ cliente_id: cliente.id, tipo: 'ENTRAMBI', stato, messaggio: `Alert ${tipo}`, errore: errMsg, inviato_at: new Date(), created_at: new Date(), updated_at: new Date() });
}

module.exports = { inviaAlert, inviaEmailAlert, inviaPushAlert };
