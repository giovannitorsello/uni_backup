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
  logger.info('Application DB connected');
  try {
    await bareosDb.raw('SELECT 1');
    logger.info('Bareos DB connected');
  } catch {
    logger.warn('Bareos DB unreachable — tape features degraded');
  }
  await migrate();
}

async function migrate() {
  const s = db.schema;

  // ---- Users ----
  await s.createTableIfNotExists('users', t => {
    t.increments('id');
    t.string('username').unique().notNullable();
    t.string('password_hash').notNullable();
    t.enu('role', ['ADMIN', 'OPERATOR']).defaultTo('OPERATOR');
    t.boolean('active').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Customers ----
  await s.createTableIfNotExists('customers', t => {
    t.increments('id');
    t.string('company_name').notNullable();
    t.string('vat_number', 20);
    t.string('tax_code', 20);
    t.string('address');
    t.string('city');
    t.string('postal_code', 10);
    t.string('province', 4);
    // IT contact at headquarters
    t.string('contact_email');
    t.string('contact_name');
    t.string('contact_phone');
    // Third-party location (CEO / external site)
    t.string('offsite_location_name');
    t.string('offsite_location_address');
    t.string('offsite_location_email');
    t.string('offsite_location_phone');
    // Bareos
    t.string('bareos_pool_name');
    t.string('bareos_client_name');
    // Tape rotation
    t.integer('rotation_period_days').defaultTo(7);
    t.timestamp('last_rotation');
    t.timestamp('next_rotation');
    // Backup backend: BAREOS | RESTIC_S3 | BOTH
    t.enu('backup_backend', ['BAREOS', 'RESTIC_S3', 'BOTH']).defaultTo('BAREOS');
    // CRM / GLPI sync
    t.string('crm_external_id');
    t.string('glpi_entity_id');
    t.timestamp('crm_last_sync');
    t.timestamp('glpi_last_sync');
    t.boolean('active').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Restic/S3 configuration per customer ----
  await s.createTableIfNotExists('restic_configs', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('CASCADE').unique();
    t.string('s3_endpoint').notNullable();
    t.string('s3_bucket').notNullable();
    t.string('s3_access_key').notNullable();
    t.text('s3_secret_key').notNullable();       // encrypted at app level
    t.text('repo_password').notNullable();        // restic repository password
    t.string('s3_region').defaultTo('us-east-1');
    t.string('s3_path').defaultTo('/');           // bucket key prefix
    // Retention policy
    t.integer('keep_daily').defaultTo(7);
    t.integer('keep_weekly').defaultTo(4);
    t.integer('keep_monthly').defaultTo(6);
    t.integer('keep_yearly').defaultTo(2);
    t.timestamp('last_snapshot');
    t.text('last_snapshot_id');
    t.timestamps(true, true);
  });

  // ---- Tape drives / libraries (vendor-side devices) ----
  await s.createTableIfNotExists('devices', t => {
    t.increments('id');
    t.string('name').notNullable();
    t.string('type');                   // Single drive / LTO-7 Library / LTO-8
    t.string('bareos_storage_name');
    t.string('bareos_sd_host');
    t.integer('bareos_sd_port').defaultTo(9103);
    t.string('device_path');            // /dev/nst0
    t.boolean('active').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Customer devices (servers running bareos-fd or restic) ----
  await s.createTableIfNotExists('customer_devices', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('CASCADE');
    t.string('name').notNullable();             // descriptive name: "Main file server"
    t.string('hostname').notNullable();          // FQDN or IP
    t.string('ip_address');
    t.string('operating_system');
    t.string('device_type');                    // SERVER | WORKSTATION | NAS | VM
    // Bareos File Daemon
    t.string('bareos_fd_name');
    t.integer('bareos_fd_port').defaultTo(9102);
    t.string('bareos_fd_password');
    t.timestamp('bareos_fd_last_seen');
    t.enu('bareos_fd_status', ['ONLINE', 'OFFLINE', 'UNKNOWN']).defaultTo('UNKNOWN');
    // Restic agent
    t.boolean('restic_enabled').defaultTo(false);
    t.text('restic_backup_paths');               // JSON array: ["/home", "/var/www"]
    t.string('restic_cron');
    t.timestamp('restic_last_backup');
    // GLPI
    t.string('glpi_computer_id');
    // Notes
    t.text('notes');
    t.boolean('active').defaultTo(true);
    t.timestamps(true, true);
  });

  // ---- Tape cartridges ----
  await s.createTableIfNotExists('tapes', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('CASCADE');
    t.integer('device_id').references('devices.id').onDelete('SET NULL');
    t.string('bareos_label').notNullable().unique();
    t.string('barcode');
    t.enu('location', ['VENDOR', 'CUSTOMER', 'OFFSITE']).notNullable();
    t.integer('delta_t').defaultTo(0);
    t.timestamp('last_backup');
    t.text('notes');
    t.timestamps(true, true);
  });

  // ---- Tape rotation history ----
  await s.createTableIfNotExists('rotations', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('CASCADE');
    t.integer('tape_id').references('tapes.id').onDelete('CASCADE');
    t.enu('from_location', ['VENDOR', 'CUSTOMER', 'OFFSITE']).notNullable();
    t.enu('to_location',   ['VENDOR', 'CUSTOMER', 'OFFSITE']).notNullable();
    t.timestamp('rotated_at').defaultTo(db.fn.now());
    t.string('operator');
    t.text('notes');
    t.timestamps(true, true);
  });

  // ---- Alert log ----
  await s.createTableIfNotExists('alert_log', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('CASCADE');
    t.enu('channel', ['EMAIL', 'PUSH', 'BOTH']);
    t.enu('status', ['SENT', 'ERROR', 'SCHEDULED']);
    t.text('message');
    t.text('error');
    t.timestamp('sent_at');
    t.timestamps(true, true);
  });

  // ---- Push subscriptions ----
  await s.createTableIfNotExists('push_subscriptions', t => {
    t.increments('id');
    t.integer('user_id');
    t.text('endpoint').notNullable();
    t.text('p256dh').notNullable();
    t.text('auth').notNullable();
    t.timestamps(true, true);
  });

  // ---- CRM sync log ----
  await s.createTableIfNotExists('crm_sync_log', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('SET NULL');
    t.enu('direction', ['CRM_TO_TG', 'TG_TO_CRM']);
    t.enu('status', ['OK', 'ERROR', 'PARTIAL']);
    t.jsonb('payload');
    t.text('error');
    t.timestamps(true, true);
  });

  // ---- GLPI sync log ----
  await s.createTableIfNotExists('glpi_sync_log', t => {
    t.increments('id');
    t.integer('customer_id').references('customers.id').onDelete('SET NULL');
    t.integer('customer_device_id').references('customer_devices.id').onDelete('SET NULL');
    t.enu('entity_type', ['COMPUTER', 'ENTITY', 'TICKET']);
    t.enu('status', ['OK', 'ERROR']);
    t.jsonb('payload');
    t.text('error');
    t.timestamps(true, true);
  });

  logger.info('Migrations completed');
}

module.exports = { db, bareosDb, initDb };