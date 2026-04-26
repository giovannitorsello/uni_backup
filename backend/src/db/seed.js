require('dotenv').config();
const bcrypt = require('bcrypt');
const { db, initDb } = require('./connection');

async function seed() {
  await initDb();

  // Admin
  if (!await db('utenti').where({ username: 'admin' }).first()) {
    await db('utenti').insert({
      username: 'admin', password_hash: await bcrypt.hash('TapeGuard2024!', 12),
      ruolo: 'ADMIN', attivo: true, created_at: new Date(), updated_at: new Date(),
    });
    console.log('Admin creato — cambia la password al primo accesso!');
  }

  // Lettore nastro
  let devId;
  const devEsistente = await db('dispositivi').where({ nome: 'LTO-Dr-01 (esempio)' }).first();
  if (!devEsistente) {
    const [row] = await db('dispositivi').insert({
      nome: 'LTO-Dr-01 (esempio)', tipo: 'Drive singolo LTO-8',
      bareos_storage_name: 'LTO-Dr-01', bareos_sd_host: 'bareos-storage',
      device_path: '/dev/nst0', attivo: true, created_at: new Date(), updated_at: new Date(),
    }).returning('id');
    devId = row.id || row;
  } else { devId = devEsistente.id; }

  // Cliente esempio — BAREOS
  if (!await db('clienti').where({ ragione_sociale: 'Acme Srl (esempio)' }).first()) {
    const [cRow] = await db('clienti').insert({
      ragione_sociale: 'Acme Srl (esempio)', partita_iva: '01234567890',
      email_referente: 'it@acme.it', nome_referente: 'Mario Rossi',
      nome_luogo_terzo: 'CEO - Via Roma 1, Lecce', email_luogo_terzo: 'ceo@acme.it',
      bareos_pool_name: 'AcmePool', bareos_client_name: 'acme-fd',
      backup_backend: 'BAREOS', periodo_giorni: 7,
      ultima_rotazione: new Date(), prossima_rotazione: new Date(Date.now() + 7*86400000),
      attivo: true, created_at: new Date(), updated_at: new Date(),
    }).returning('id');
    const cId = cRow.id || cRow;

    for (const [pos, delta, label] of [['FORNITORE',0,'VOL-ACME-001'],['SEDE',-1,'VOL-ACME-002'],['TERZO',-2,'VOL-ACME-003']]) {
      await db('cassette').insert({ cliente_id: cId, dispositivo_id: devId, label_bareos: label, posizione: pos, delta_t: delta, created_at: new Date(), updated_at: new Date() });
    }

    // Dispositivo cliente
    await db('dispositivi_cliente').insert({
      cliente_id: cId, nome: 'File server principale', hostname: 'fs01.acme.it',
      ip_address: '192.168.1.10', sistema_operativo: 'Windows Server 2022',
      tipo_device: 'SERVER', bareos_fd_name: 'acme-fd', bareos_fd_port: 9102,
      bareos_fd_status: 'SCONOSCIUTO', restic_enabled: false,
      attivo: true, created_at: new Date(), updated_at: new Date(),
    });
    console.log('Cliente Bareos esempio creato');
  }

  // Cliente esempio — RESTIC_S3
  if (!await db('clienti').where({ ragione_sociale: 'Delta Net (esempio S3)' }).first()) {
    const [cRow] = await db('clienti').insert({
      ragione_sociale: 'Delta Net (esempio S3)', partita_iva: '09876543210',
      email_referente: 'sys@deltanet.it', nome_referente: 'Laura Bianchi',
      backup_backend: 'RESTIC_S3', periodo_giorni: 15,
      attivo: true, created_at: new Date(), updated_at: new Date(),
    }).returning('id');
    const cId = cRow.id || cRow;

    await db('restic_configs').insert({
      cliente_id: cId, s3_endpoint: 'http://minio:9000',
      s3_bucket: 'backup-deltanet', s3_access_key: 'tapeguard',
      s3_secret_key: 'CAMBIA_QUESTA_SECRET', repo_password: 'CAMBIA_QUESTA_PASSWORD',
      s3_region: 'us-east-1', s3_path: '/', keep_daily: 7, keep_weekly: 4,
      keep_monthly: 6, keep_yearly: 2, created_at: new Date(), updated_at: new Date(),
    });

    await db('dispositivi_cliente').insert({
      cliente_id: cId, nome: 'NAS backup', hostname: 'nas01.deltanet.it',
      ip_address: '10.0.0.5', sistema_operativo: 'Ubuntu 22.04 LTS',
      tipo_device: 'NAS', restic_enabled: true,
      restic_backup_paths: JSON.stringify(['/data', '/home']),
      restic_cron: '0 2 * * *', bareos_fd_status: 'SCONOSCIUTO',
      attivo: true, created_at: new Date(), updated_at: new Date(),
    });
    console.log('Cliente Restic/S3 esempio creato');
  }

  console.log('Seed completato.');
  process.exit(0);
}

seed().catch(e => { console.error(e); process.exit(1); });
