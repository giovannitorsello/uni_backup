/**
 * ResticService
 * Wrapper attorno al binario restic per backup su S3-compatible storage.
 * Ogni cliente ha la propria configurazione repo nel DB (restic_configs).
 *
 * Variabili d'ambiente restic:
 *   RESTIC_REPOSITORY  s3:endpoint/bucket/path
 *   RESTIC_PASSWORD    password repository
 *   AWS_ACCESS_KEY_ID
 *   AWS_SECRET_ACCESS_KEY
 */

const { spawn } = require('child_process');
const { db }    = require('../db/connection');
const logger    = require('../utils/logger');

// -------------------------------------------------------------------
// Costruisce l'ambiente per un dato cliente
// -------------------------------------------------------------------
async function getEnvForCliente(clienteId) {
  const cfg = await db('restic_configs').where({ cliente_id: clienteId }).first();
  if (!cfg) throw new Error(`Nessuna configurazione Restic per cliente ${clienteId}`);

  const endpoint = cfg.s3_endpoint.replace(/\/$/, '');
  const repo = `s3:${endpoint}/${cfg.s3_bucket}${cfg.s3_path}`;

  return {
    env: {
      PATH:                 process.env.PATH,
      HOME:                 process.env.HOME || '/root',
      RESTIC_REPOSITORY:    repo,
      RESTIC_PASSWORD:      cfg.repo_password,
      RESTIC_CACHE_DIR:     process.env.RESTIC_CACHE_DIR || '/restic-cache',
      AWS_ACCESS_KEY_ID:    cfg.s3_access_key,
      AWS_SECRET_ACCESS_KEY: cfg.s3_secret_key,
    },
    cfg,
  };
}

// -------------------------------------------------------------------
// Esegui comando restic generico
// -------------------------------------------------------------------
function runRestic(args, env, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    logger.info(`restic ${args.join(' ')}`);
    const proc = spawn('restic', args, { env });

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', d => { stdout += d.toString(); });
    proc.stderr.on('data', d => { stderr += d.toString(); });

    const timer = setTimeout(() => {
      proc.kill();
      reject(new Error(`restic timeout: ${args[0]}`));
    }, timeoutMs);

    proc.on('close', code => {
      clearTimeout(timer);
      if (code !== 0) {
        reject(new Error(`restic ${args[0]} exit ${code}: ${stderr.trim()}`));
      } else {
        resolve({ stdout: stdout.trim(), stderr: stderr.trim() });
      }
    });
  });
}

// -------------------------------------------------------------------
// Inizializza repository (da fare una volta per cliente)
// -------------------------------------------------------------------
async function initRepo(clienteId) {
  const { env } = await getEnvForCliente(clienteId);
  return runRestic(['init'], env);
}

// -------------------------------------------------------------------
// Esegui backup di un dispositivo cliente
// -------------------------------------------------------------------
async function backup(clienteId, deviceId, paths, tags = []) {
  const { env, cfg } = await getEnvForCliente(clienteId);
  const device = await db('dispositivi_cliente').where({ id: deviceId }).first();

  const allTags = [
    `cliente:${clienteId}`,
    `device:${deviceId}`,
    ...(device ? [`hostname:${device.hostname}`] : []),
    ...tags,
  ];

  const tagArgs = allTags.flatMap(t => ['--tag', t]);
  const args = ['backup', '--json', ...tagArgs, ...paths];

  const result = await runRestic(args, env, 600000); // 10 min timeout

  // Aggiorna timestamp ultimo backup
  await db('restic_configs').where({ cliente_id: clienteId })
    .update({ ultimo_snapshot: new Date(), updated_at: new Date() });

  if (device) {
    await db('dispositivi_cliente').where({ id: deviceId })
      .update({ restic_last_backup: new Date(), updated_at: new Date() });
  }

  try { return JSON.parse(result.stdout); }
  catch { return result; }
}

// -------------------------------------------------------------------
// Lista snapshot
// -------------------------------------------------------------------
async function snapshots(clienteId, { deviceId, limit } = {}) {
  const { env } = await getEnvForCliente(clienteId);
  const args = ['snapshots', '--json'];
  if (deviceId) {
    const d = await db('dispositivi_cliente').where({ id: deviceId }).first();
    if (d) args.push('--tag', `device:${deviceId}`);
  }
  if (limit) args.push('--last', String(limit));

  const result = await runRestic(args, env);
  try { return JSON.parse(result.stdout); }
  catch { return []; }
}

// -------------------------------------------------------------------
// Forget + prune (applica retention policy)
// -------------------------------------------------------------------
async function forget(clienteId) {
  const { env, cfg } = await getEnvForCliente(clienteId);
  const args = [
    'forget', '--prune',
    '--keep-daily',   String(cfg.keep_daily),
    '--keep-weekly',  String(cfg.keep_weekly),
    '--keep-monthly', String(cfg.keep_monthly),
    '--keep-yearly',  String(cfg.keep_yearly),
    '--json',
  ];
  const result = await runRestic(args, env, 300000);
  try { return JSON.parse(result.stdout); }
  catch { return result; }
}

// -------------------------------------------------------------------
// Check integrità repository
// -------------------------------------------------------------------
async function check(clienteId) {
  const { env } = await getEnvForCliente(clienteId);
  return runRestic(['check'], env, 300000);
}

// -------------------------------------------------------------------
// Stats repository
// -------------------------------------------------------------------
async function stats(clienteId) {
  const { env } = await getEnvForCliente(clienteId);
  const result = await runRestic(['stats', '--json'], env);
  try { return JSON.parse(result.stdout); }
  catch { return {}; }
}

// -------------------------------------------------------------------
// Restore di uno snapshot
// -------------------------------------------------------------------
async function restore(clienteId, snapshotId, targetPath) {
  const { env } = await getEnvForCliente(clienteId);
  const args = ['restore', snapshotId, '--target', targetPath];
  return runRestic(args, env, 900000); // 15 min
}

module.exports = { initRepo, backup, snapshots, forget, check, stats, restore };
