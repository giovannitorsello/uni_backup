# Universal Easy Backup 

Gestione backup multi-backend con rotazione cassette e integrazione CRM/GLPI.

## Backend di backup supportati

| Backend | Tecnologia | Caso d'uso |
|---|---|---|
| `BAREOS` | Bareos Director + nastro LTO | Backup su cassetta fisica con rotazione off-site |
| `RESTIC_S3` | Restic + S3-compatible | Backup cloud su MinIO / AWS S3 / Wasabi / Backblaze B2 |
| `ENTRAMBI` | Bareos + Restic | Ridondanza massima nastro + cloud |

## Schema rotazione cassette (solo BAREOS / ENTRAMBI)

```
Posizione    Delta-T   Descrizione
─────────────────────────────────────────────
FORNITORE     T+0      Copia più recente, presso di noi
SEDE          T-1      Backup 1 periodo fa, in sede cliente
TERZO         T-2      Backup 2 periodi fa, CEO / luogo terzo
```

Ciclo (7 / 15 / 30 giorni, per cliente):
1. TERZO → FORNITORE (ritiro + scrittura nuovo backup)
2. SEDE  → TERZO
3. FORNITORE → SEDE (consegna nastro appena scritto)

## Avvio rapido

```bash
cp .env.example .env        # compila TUTTI i campi
make gen-certs              # SSL self-signed per sviluppo
make gen-vapid              # chiavi VAPID → copia in .env
make up                     # build + avvio
make seed                   # admin + dati esempio
# → https://localhost  (admin / TapeGuard2024! — cambia subito!)
```

## Struttura del progetto

```
tapeguard/
├── docker-compose.yml
├── .env.example
├── Makefile
├── README.md
│
├── backend/
│   ├── Dockerfile              # Node 20 + restic binary
│   ├── package.json
│   └── src/
│       ├── server.js
│       ├── db/
│       │   ├── connection.js   # Knex + migrazioni auto (14 tabelle)
│       │   └── seed.js
│       ├── routes/
│       │   ├── auth.js
│       │   ├── clienti.js      # CRUD + POST /:id/rotazione
│       │   ├── cassette.js
│       │   ├── rotazioni.js
│       │   ├── dispositivi.js          # lettori nastro fornitore
│       │   ├── dispositiviCliente.js   # anagrafica device clienti
│       │   ├── restic.js               # operazioni restic/S3
│       │   ├── bareos.js               # proxy catalogo + bconsole
│       │   ├── alert.js
│       │   └── sync.js                 # CRM webhook + GLPI
│       ├── services/
│       │   ├── rotazioneService.js     # logica rotazione 3 cassette
│       │   ├── alertService.js         # email + web push
│       │   ├── bareosService.js        # Bareos catalog + bconsole
│       │   ├── resticService.js        # wrapper CLI restic
│       │   ├── crmSyncService.js       # sync CRM esterno
│       │   └── glpiService.js          # GLPI REST API
│       ├── scheduler/
│       │   └── index.js        # node-cron alert + ticket GLPI
│       └── utils/
│           ├── auth.js         # JWT middleware
│           └── logger.js       # Winston
│
├── frontend/
│   ├── Dockerfile
│   ├── quasar.config.js
│   └── src/
│       ├── boot/axios.js
│       ├── stores/backup.js    # Pinia store
│       └── pages/
│           ├── DashboardPage.vue
│           ├── ClientiPage.vue
│           ├── DispositiviClientePage.vue
│           └── SyncPage.vue
│
└── docker/
    ├── postgres/init-multi-db.sh
    ├── bareos/
    │   ├── bareos-dir.conf
    │   ├── bareos-sd.conf
    │   └── bareos-dir.d/cliente-acme.conf   ← template
    └── nginx/nginx.conf
```

## API principali

```
# Auth
POST   /api/auth/login
GET    /api/auth/me

# Clienti
GET    /api/clienti?backend=BAREOS|RESTIC_S3|ENTRAMBI
POST   /api/clienti
PATCH  /api/clienti/:id
POST   /api/clienti/:id/rotazione          ← esegue rotazione 3 cassette
DELETE /api/clienti/:id                    ← soft delete

# Cassette nastro
GET    /api/cassette?cliente_id=&posizione=FORNITORE|SEDE|TERZO
POST   /api/cassette
PATCH  /api/cassette/:id

# Dispositivi cliente (anagrafica Bareos FD + Restic)
GET    /api/dispositivi-cliente?cliente_id=
POST   /api/dispositivi-cliente
PATCH  /api/dispositivi-cliente/:id
DELETE /api/dispositivi-cliente/:id
GET    /api/dispositivi-cliente/:id/bareos-status  ← test connessione FD

# Restic / S3
GET    /api/restic/config/:clienteId
POST   /api/restic/config/:clienteId        ← salva config S3
POST   /api/restic/:clienteId/init          ← inizializza repo
GET    /api/restic/:clienteId/snapshots
POST   /api/restic/:clienteId/backup        ← backup manuale
POST   /api/restic/:clienteId/forget        ← applica retention
GET    /api/restic/:clienteId/stats
POST   /api/restic/:clienteId/check

# Bareos (read + comandi)
GET    /api/bareos/volumi?pool=
GET    /api/bareos/pool
GET    /api/bareos/storage
GET    /api/bareos/jobs/:clientName
GET    /api/bareos/status/director
GET    /api/bareos/status/storage/:nome
GET    /api/bareos/status/client/:nome
POST   /api/bareos/label
POST   /api/bareos/volume-status

# Alert
GET    /api/alert
POST   /api/alert/invia/:clienteId
POST   /api/alert/run-job                   ← esegui subito lo scheduler
POST   /api/alert/push-subscribe            ← registra Web Push

# Sync CRM
POST   /api/sync/crm/webhook                ← riceve eventi dal CRM (NO auth)
POST   /api/sync/crm/pull                   ← pull manuale CRM → TapeGuard
POST   /api/sync/crm/push/:clienteId        ← push TapeGuard → CRM
GET    /api/sync/crm/log

# Sync GLPI
GET    /api/sync/glpi/entities
GET    /api/sync/glpi/sync-entities
POST   /api/sync/glpi/sync-computers/:clienteId
POST   /api/sync/glpi/ticket
GET    /api/sync/glpi/log
```

## Aggiungere un cliente Bareos

```bash
# 1. Crea config in docker/bareos/bareos-dir.d/cliente-NOME.conf
cp docker/bareos/bareos-dir.d/cliente-acme.conf \
   docker/bareos/bareos-dir.d/cliente-nuovazienda.conf
# Modifica: Name, Address, Password, Pool name, Label Format

# 2. Ricarica Bareos Director
make bareos-reload

# 3. Crea il cliente in TapeGuard (via UI o API)
curl -X POST https://localhost/api/clienti \
  -H "Authorization: Bearer TOKEN" \
  -d '{"ragione_sociale":"Nuova Azienda","backup_backend":"BAREOS","periodo_giorni":7,...}'

# 4. Aggiungi le 3 cassette
# Posizioni: FORNITORE (delta_t=0), SEDE (delta_t=-1), TERZO (delta_t=-2)
```

## Aggiungere un cliente Restic/S3

```bash
# 1. Crea cliente in TapeGuard con backup_backend=RESTIC_S3
# 2. Configura S3 via API o UI
curl -X POST https://localhost/api/restic/config/CLIENT_ID \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "s3_endpoint":"https://s3.eu-central-1.amazonaws.com",
    "s3_bucket":"backup-miazienda",
    "s3_access_key":"AKIAIOSFODNN7EXAMPLE",
    "s3_secret_key":"wJalrXUtnFEMI/...",
    "repo_password":"password-restic-sicura",
    "keep_daily":7,"keep_weekly":4,"keep_monthly":6,"keep_yearly":2
  }'

# 3. Inizializza il repository
curl -X POST https://localhost/api/restic/CLIENT_ID/init \
  -H "Authorization: Bearer TOKEN"
```

## Configurare integrazione GLPI

```bash
# Nel .env:
GLPI_URL=https://glpi.tua-azienda.it
GLPI_APP_TOKEN=...  # da GLPI: Configurazione → API → Token applicazione
GLPI_USER_TOKEN=... # da GLPI: Profilo → API → Token utente

# Nel DB: imposta glpi_entity_id per ogni cliente
# L'ID Entity corrisponde all'entità GLPI del cliente

# I ticket vengono aperti automaticamente dallo scheduler
# per le rotazioni scadute (urgency=5)
```

## Configurare integrazione CRM

```bash
# Nel .env:
CRM_API_URL=https://crm.tua-azienda.it
CRM_API_KEY=api_key_del_crm
CRM_WEBHOOK_SECRET=secret_per_hmac_sha256

# Sul CRM: configura webhook verso
# https://tapeguard.tua-azienda.it/api/sync/crm/webhook
# Header: X-CRM-Event: contact.created|contact.updated|contact.deleted
# Header: X-CRM-Signature: hmac-sha256 del body

# Il field mapping di default è in src/services/crmSyncService.js
# Personalizza DEFAULT_FIELD_MAP per adattarlo al tuo CRM
```
