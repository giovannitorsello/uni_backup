const knex   = require('knex');
const logger = require('../utils/logger');

const db = knex({
  client: 'pg',
  connection: {
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME     || 'tapeguard',
    user:     process.env.DB_USER     || 'tapeguard',
    password: process.env.DB_PASSWORD,
  },
  pool: { min: 2, max: 10 },
});

const bareosDb = knex({
  client: 'pg',
  connection: {
    host:     process.env.BAREOS_DB_HOST || 'localhost',
    port:     5432,
    database: process.env.BAREOS_DB_NAME || 'bareos',
    user:     process.env.BAREOS_DB_USER || 'tapeguard',
    password: process.env.BAREOS_DB_PASSWORD,
  },
  pool: { min: 1, max: 5 },
});

async function initDb() {
  await db.raw('SELECT 1');
  logger.info('DB applicativo connesso');
  try {
    await bareosDb.raw('SELECT 1');
    logger.info('DB Bareos connesso');
  } catch {
    logger.warn('DB Bareos non raggiungibile — funzionalità nastro degradate');
  }
  await migrate();
}

async function migrate() {
  const s = db.schema;

  // ---- Utenti ----
  await s.createTableIfNotExists('utenti', t => {
    t.increments('id');
    t.string('username').unique().notNullable();
    t.string('password_hash').notNullable();
    t.enu('ruolo', ['ADMIN', 'OPERATORE']).defaultTo('OPERATORE');
    t.boolean('attivo').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Clienti ----
  await s.createTableIfNotExists('clienti', t => {
    t.increments('id');
    t.string('ragione_sociale').notNullable();
    t.string('partita_iva', 20);
    t.string('codice_fiscale', 20);
    t.string('indirizzo');
    t.string('citta');
    t.string('cap', 10);
    t.string('provincia', 4);
    // Referente IT sede
    t.string('email_referente');
    t.string('nome_referente');
    t.string('telefono_referente');
    // Luogo terzo (CEO / sede esterna)
    t.string('nome_luogo_terzo');
    t.string('indirizzo_luogo_terzo');
    t.string('email_luogo_terzo');
    t.string('telefono_luogo_terzo');
    // Bareos
    t.string('bareos_pool_name');
    t.string('bareos_client_name');
    // Rotazione nastro
    t.integer('periodo_giorni').defaultTo(7);
    t.timestamp('ultima_rotazione');
    t.timestamp('prossima_rotazione');
    // Backend backup: BAREOS | RESTIC_S3 | ENTRAMBI
    t.enu('backup_backend', ['BAREOS', 'RESTIC_S3', 'ENTRAMBI']).defaultTo('BAREOS');
    // Sync CRM / GLPI
    t.string('crm_external_id');          // ID nel CRM esterno
    t.string('glpi_entity_id');           // Entity ID in GLPI
    t.timestamp('crm_last_sync');
    t.timestamp('glpi_last_sync');
    t.boolean('attivo').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Configurazione Restic/S3 per cliente ----
  await s.createTableIfNotExists('restic_configs', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('CASCADE').unique();
    t.string('s3_endpoint').notNullable();      // es. https://s3.eu-central-1.amazonaws.com
    t.string('s3_bucket').notNullable();        // es. backup-acme-srl
    t.string('s3_access_key').notNullable();
    t.text('s3_secret_key').notNullable();      // crittografato a livello app
    t.text('repo_password').notNullable();       // password repository restic
    t.string('s3_region').defaultTo('us-east-1');
    t.string('s3_path').defaultTo('/');          // prefisso nel bucket
    // Retention policy
    t.integer('keep_daily').defaultTo(7);
    t.integer('keep_weekly').defaultTo(4);
    t.integer('keep_monthly').defaultTo(6);
    t.integer('keep_yearly').defaultTo(2);
    t.timestamp('ultimo_snapshot');
    t.text('ultimo_snapshot_id');
    t.timestamps(true, true);
  });

  // ---- Lettori nastro / librerie (dispositivi del FORNITORE) ----
  await s.createTableIfNotExists('dispositivi', t => {
    t.increments('id');
    t.string('nome').notNullable();
    t.string('tipo');                  // Drive singolo / Libreria LTO-7 / LTO-8
    t.string('bareos_storage_name');
    t.string('bareos_sd_host');
    t.integer('bareos_sd_port').defaultTo(9103);
    t.string('device_path');           // /dev/nst0
    t.boolean('attivo').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Anagrafica dispositivi CLIENTE (server con bareos-fd o restic) ----
  await s.createTableIfNotExists('dispositivi_cliente', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('CASCADE');
    t.string('nome').notNullable();           // nome descrittivo: "File server principale"
    t.string('hostname').notNullable();       // FQDN o IP
    t.string('ip_address');
    t.string('sistema_operativo');            // Windows Server 2022, Ubuntu 22.04...
    t.string('tipo_device');                 // SERVER | WORKSTATION | NAS | VM
    // Bareos File Daemon
    t.string('bareos_fd_name');              // nome in bareos (acme-fileserver-fd)
    t.integer('bareos_fd_port').defaultTo(9102);
    t.string('bareos_fd_password');          // password FD
    t.timestamp('bareos_fd_last_seen');
    t.enu('bareos_fd_status', ['ONLINE', 'OFFLINE', 'SCONOSCIUTO']).defaultTo('SCONOSCIUTO');
    // Restic agent (se installato)
    t.boolean('restic_enabled').defaultTo(false);
    t.text('restic_backup_paths');            // JSON array: ["/home", "/var/www"]
    t.string('restic_cron');                  // cron del backup restic su questo device
    t.timestamp('restic_last_backup');
    // GLPI
    t.string('glpi_computer_id');            // ID computer in GLPI
    // Note
    t.text('note');
    t.boolean('attivo').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Cassette nastro ----
  await s.createTableIfNotExists('cassette', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('CASCADE');
    t.integer('dispositivo_id').references('dispositivi.id').onDelete('SET NULL');
    t.string('label_bareos').notNullable().unique();
    t.string('barcode');
    t.enu('posizione', ['FORNITORE', 'SEDE', 'TERZO']).notNullable();
    t.integer('delta_t').defaultTo(0);
    t.timestamp('data_ultimo_backup');
    t.text('note');
    t.timestamps(true, true);
  });

  // ---- Storico rotazioni nastro ----
  await s.createTableIfNotExists('rotazioni', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('CASCADE');
    t.integer('cassetta_id').references('cassette.id').onDelete('CASCADE');
    t.enu('posizione_da', ['FORNITORE', 'SEDE', 'TERZO']).notNullable();
    t.enu('posizione_a',  ['FORNITORE', 'SEDE', 'TERZO']).notNullable();
    t.timestamp('data_rotazione').defaultTo(db.fn.now());
    t.string('operatore');
    t.text('note');
    t.timestamps(true, true);
  });

  // ---- Alert log ----
  await s.createTableIfNotExists('alert_log', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('CASCADE');
    t.enu('tipo', ['EMAIL', 'PUSH', 'ENTRAMBI']);
    t.enu('stato', ['INVIATO', 'ERRORE', 'SCHEDULATO']);
    t.text('messaggio');
    t.text('errore');
    t.timestamp('inviato_at');
    t.timestamps(true, true);
  });

  // ---- Push subscriptions ----
  await s.createTableIfNotExists('push_subscriptions', t => {
    t.increments('id');
    t.integer('utente_id');
    t.text('endpoint').notNullable();
    t.text('p256dh').notNullable();
    t.text('auth').notNullable();
    t.timestamps(true, true);
  });

  // ---- CRM sync log ----
  await s.createTableIfNotExists('crm_sync_log', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('SET NULL');
    t.enu('direzione', ['CRM_TO_TG', 'TG_TO_CRM']);
    t.enu('stato', ['OK', 'ERRORE', 'PARZIALE']);
    t.jsonb('payload');
    t.text('errore');
    t.timestamps(true, true);
  });

  // ---- GLPI sync log ----
  await s.createTableIfNotExists('glpi_sync_log', t => {
    t.increments('id');
    t.integer('cliente_id').references('clienti.id').onDelete('SET NULL');
    t.integer('dispositivo_cliente_id').references('dispositivi_cliente.id').onDelete('SET NULL');
    t.enu('entity_type', ['COMPUTER', 'ENTITY', 'TICKET']);
    t.enu('stato', ['OK', 'ERRORE']);
    t.jsonb('payload');
    t.text('errore');
    t.timestamps(true, true);
  });

  logger.info('Migrazioni completate');
}

module.exports = { db, bareosDb, initDb };
