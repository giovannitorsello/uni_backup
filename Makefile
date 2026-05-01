.PHONY: help clone-bareos up down logs seed ps restart-api gen-certs gen-vapid backup-db bareos-reload bareos-status

BAREOS_GIT_TAG ?= bareos-25
BUILD_JOBS      ?= 4

help:
	@echo ""
	@echo "  Uni Easy Backup v2 — comandi disponibili"
	@echo ""
	@echo "  Primo avvio (ordine obbligatorio):"
	@echo "    make clone-bareos   Clona sorgenti Bareos in locale (una sola volta)"
	@echo "    make gen-certs      Genera certificati SSL self-signed"
	@echo "    make gen-vapid      Genera chiavi VAPID per Web Push"
	@echo "    make up             Build container e avvio"
	@echo "    make seed           Crea admin e dati di esempio"
	@echo ""
	@echo "  Nota: la prima 'make up' compila Bareos da sorgente."
	@echo "  Durata stimata: 20-60 minuti. Le esecuzioni successive"
	@echo "  usano la cache Docker e sono istantanee."
	@echo ""
	@echo "  Operativi:"
	@echo "    make logs           Segui i log in tempo reale"
	@echo "    make ps             Stato container"
	@echo "    make restart-api    Riavvia solo il backend Node.js"
	@echo "    make backup-db      Esporta il DB applicativo"
	@echo "    make bareos-reload  Ricarica config Bareos Director"
	@echo "    make bareos-status  Stato Director Bareos"
	@echo ""

-include .env
check-env:
	@grep -P '^\w+ = ' .env && \
    { echo "ERRORE: .env contiene variabili con spazi intorno a '='"; exit 1; } || true

clone-bareos:
	@if [ -d "src/bareos/bareos-src/.git" ]; then \
		echo ""; \
		echo "  Sorgenti Bareos già presenti in src/bareos/bareos-src/"; \
		echo "  Branch selezionato: $(BAREOS_GIT_TAG)"; \
		echo "  Commit clonato: $$(git -C src/bareos/bareos-src describe --tags --always 2>/dev/null || echo 'N/D')"; \
		echo ""; \
		echo "  Per cambiare versione:"; \
		echo "    rm -rf src/bareos/bareos-src && make clone-bareos"; \
		echo ""; \
	else \
		echo ""; \
		echo "  Clonando Bareos"; \
		echo "  (solo il commit di punta, senza history — ~200MB)"; \
		echo ""; \
		git clone https://github.com/bareos/bareos.git src/bareos/bareos-src; \
		git -C src/bareos/bareos-src/ switch $(BAREOS_GIT_TAG); \
		git -C src/bareos/bareos-src describe --tags --always > src/bareos/bareos-src/VERSION; \
		echo ""; \
		echo "  Clone completato: $$(git -C src/bareos/bareos-src describe --tags --always)"; \
		echo "  Branch selezionato: $(BAREOS_GIT_TAG)"; \
		echo "  I sorgenti sono ora fissi. Puoi eseguire 'make up'."; \
		echo ""; \
	fi

up:
	@if [ ! -d "src/bareos/bareos-src/.git" ]; then \
		echo "ERRORE: sorgenti Bareos non trovati."; \
		echo "Esegui prima: make clone-bareos"; \
		exit 1; \
	fi
	docker compose up -d --build

up-dev:
	docker compose -f docker-compose.yml -f docker-compose.override.dev.yml up -d

up-prod:
	docker compose -f docker-compose.yml -f docker-compose.override.prod.yml up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

restart-api:
	docker compose restart api

seed:
	docker compose exec api node src/db/seed.js
	@echo ""
	@echo "  Accesso: https://localhost"
	@echo "  Utente:  admin / ueb2024!  ← CAMBIA SUBITO"
	@echo ""

-include .env
export

APP_DOMAIN ?= 
CERTS_DIR  := docker/certs

-include .env
export

APP_DOMAIN ?= localhost
CERTS_DIR  ?= docker/certs

# ─── CA ──────────────────────────────────────────────────────────────────────
gen-ca:
	@mkdir -p $(CERTS_DIR)
	@echo "→ Generazione CA per $(APP_DOMAIN)..."
	# Chiave privata della CA
	openssl genrsa -out $(CERTS_DIR)/ca.key 4096
	# Certificato CA auto-firmato (10 anni)
	openssl req -x509 -new -nodes \
		-key  $(CERTS_DIR)/ca.key \
		-days 3650 \
		-out  $(CERTS_DIR)/ca.crt \
		-subj "/C=IT/ST=Puglia/L=Lecce/O=ueb CA/CN=U Root CA"
	@echo "✓ CA generata in $(CERTS_DIR)/ca.crt"
	@echo "  → Importa $(CERTS_DIR)/ca.crt nel trust store del browser/OS per eliminare gli avvisi."

# ─── Certificato server firmato dalla CA ─────────────────────────────────────
gen-certs: gen-ca
	@echo "→ Generazione certificato server per *.$(APP_DOMAIN)..."
	# Chiave privata del server
	openssl genrsa -out $(CERTS_DIR)/ueb.key 2048
	# CSR
	openssl req -new \
		-key  $(CERTS_DIR)/ueb.key \
		-out  $(CERTS_DIR)/ueb.csr \
		-subj "/C=IT/ST=Puglia/L=Lecce/O=ueb/CN=$(APP_DOMAIN)"
	# Estensioni SAN in un file temporaneo
	@printf '[ext]\n\
subjectAltName=DNS:$(APP_DOMAIN),DNS:*.$(APP_DOMAIN)\n\
keyUsage=digitalSignature,keyEncipherment\n\
extendedKeyUsage=serverAuth\n' > $(CERTS_DIR)/ueb.ext
	# Firma del certificato con la CA (2 anni)
	openssl x509 -req \
		-in      $(CERTS_DIR)/ueb.csr \
		-CA      $(CERTS_DIR)/ca.crt \
		-CAkey   $(CERTS_DIR)/ca.key \
		-CAcreateserial \
		-days    730 \
		-extfile $(CERTS_DIR)/ueb.ext \
		-out     $(CERTS_DIR)/ueb.crt
	# Pulizia file intermedi
	@rm -f $(CERTS_DIR)/ueb.csr $(CERTS_DIR)/ueb.ext $(CERTS_DIR)/ca.srl
	@echo "✓ Certificato server generato e firmato in $(CERTS_DIR)/ueb.crt"

# ─── Rimozione certificati ────────────────────────────────────────────────────
clean-certs:
	@rm -rf $(CERTS_DIR)
	@echo "✓ Certificati rimossi."

gen-vapid:
	@echo "Generazione chiavi VAPID..."
	@cd src/backend && \
	  npm install --no-save --silent web-push 2>/dev/null; \
	  node -e "\
	    const wp = require('web-push'); \
	    const k = wp.generateVAPIDKeys(); \
	    console.log(''); \
	    console.log('VAPID_PUBLIC_KEY=' + k.publicKey); \
	    console.log('VAPID_PRIVATE_KEY=' + k.privateKey); \
	    console.log(''); \
	  "
	@echo "Copia le righe precedenti nel file .env"

backup-db:
	@mkdir -p backups
	docker compose exec postgres pg_dump -U ueb ueb \
		> backups/ueb-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup salvato in backups/"

bareos-reload:
	docker compose exec bareos-director bconsole <<< "reload"
	@echo "Configurazione Bareos ricaricata"

bareos-status:
	docker compose exec bareos-director bconsole <<< "status director"


# ── mhvtl ────────────────────────────────────────────────────
MHVTL_DIR    ?= /opt/mhvtl
MHVTL_DRIVES ?= 2
MHVTL_SLOTS  ?= 20
MHVTL_TAPES  ?= 10
MHVTL_MEDIA  ?= LTO8

mhvtl-init:
	@MHVTL_DIR=$(MHVTL_DIR) \
	 MHVTL_DRIVES=$(MHVTL_DRIVES) \
	 MHVTL_SLOTS=$(MHVTL_SLOTS) \
	 MHVTL_TAPES=$(MHVTL_TAPES) \
	 MHVTL_MEDIA=$(MHVTL_MEDIA) \
	 sudo bash src/mhvtl/scripts/mhvtl-tearinit.sh

mhvtl-stop:
	@sudo bash src/mhvtl/scripts/mhvtl-teardown.sh

mhvtl-clean:
	@MHVTL_CLEAN=yes sudo bash src/mhvtl/scripts/mhvtl-down.sh

clean-all:
	@rm -rf ./docker/postgres
	@rm -rf ./docker/bareos
	@rm -rf ./docker/bareos-webui
	@rm -rf ./docker/certs
	@rm -rf ./src/bareos/bareos-src
	@rm -rf ./src/bareos/build
	@rm -rf ./src/backend/node_modules
	@rm -rf ./src/backend/dist
	@rm -rf ./src/frontend/node_modules
	@rm -rf ./src/frontend/dist
	@echo "✓ Pulizia completa eseguita. Tutti i dati, certificati e sorgenti Bareos sono stati rimossi."


