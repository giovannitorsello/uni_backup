.PHONY: help clone-bareos up down logs seed ps restart-api gen-certs gen-vapid backup-db bareos-reload bareos-status

BAREOS_GIT_TAG ?= bareos-25
BUILD_JOBS      ?= 4

help:
	@echo ""
	@echo "  TapeGuard v2 — comandi disponibili"
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

clone-bareos:
	@if [ -d "docker/bareos/bareos-src/.git" ]; then \
		echo ""; \
		echo "  Sorgenti Bareos già presenti in docker/bareos/bareos-src/"; \
		echo "  Branch selezionato: $(BAREOS_GIT_TAG)"; \
		echo "  Commit clonato: $$(git -C docker/bareos/bareos-src describe --tags --always 2>/dev/null || echo 'N/D')"; \
		echo ""; \
		echo "  Per cambiare versione:"; \
		echo "    rm -rf docker/bareos/bareos-src && make clone-bareos"; \
		echo ""; \
	else \
		echo ""; \
		echo "  Clonando Bareos"; \
		echo "  (solo il commit di punta, senza history — ~200MB)"; \
		echo ""; \
		git clone https://github.com/bareos/bareos.git docker/bareos/bareos-src; \
		git -C docker/bareos/bareos-src/ switch $(BAREOS_GIT_TAG); \
		git -C docker/bareos/bareos-src describe --tags --always > docker/bareos/bareos-src/VERSION; \
		echo ""; \
		echo "  Clone completato: $$(git -C docker/bareos/bareos-src describe --tags --always)"; \
		echo "  Branch selezionato: $(BAREOS_GIT_TAG)"; \
		echo "  I sorgenti sono ora fissi. Puoi eseguire 'make up'."; \
		echo ""; \
	fi

up:
	@if [ ! -d "docker/bareos/bareos-src/.git" ]; then \
		echo "ERRORE: sorgenti Bareos non trovati."; \
		echo "Esegui prima: make clone-bareos"; \
		exit 1; \
	fi
	docker compose up -d --build

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
	@echo "  Utente:  admin / TapeGuard2024!  ← CAMBIA SUBITO"
	@echo ""

gen-certs:
	@mkdir -p docker/nginx/certs
	openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
		-keyout docker/nginx/certs/tapeguard.key \
		-out    docker/nginx/certs/tapeguard.crt \
		-subj "/C=IT/ST=Puglia/L=Lecce/O=TapeGuard/CN=localhost"
	@echo "Certificato generato in docker/nginx/certs/"

gen-vapid:
	@echo "Generazione chiavi VAPID..."
	@cd backend && \
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
	docker compose exec postgres pg_dump -U tapeguard tapeguard \
		> backups/tapeguard-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup salvato in backups/"

bareos-reload:
	docker compose exec bareos-director bconsole <<< "reload"
	@echo "Configurazione Bareos ricaricata"

bareos-status:
	docker compose exec bareos-director bconsole <<< "status director"
