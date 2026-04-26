# =============================================================
# TapeGuard API — Node.js 20 LTS
# Multi-stage: deps → runtime
# =============================================================

# --- Stage 1: dipendenze Node ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Usa npm install (compatibile con e senza package-lock.json)
RUN npm install --omit=dev --no-audit --no-fund

# --- Stage 2: runtime ---
FROM node:20-alpine AS runtime
WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata wget

# Restic: download binario diretto da GitHub Releases
# (non disponibile nei repo Alpine standard su tutte le versioni)
ARG RESTIC_VERSION=0.16.4
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    wget -q "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_${ARCH}.bz2" \
         -O /tmp/restic.bz2 && \
    bunzip2 /tmp/restic.bz2 && \
    mv /tmp/restic /usr/local/bin/restic && \
    chmod +x /usr/local/bin/restic && \
    restic version

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN mkdir -p logs /restic-cache && chown -R node:node /app /restic-cache
USER node

EXPOSE 3000
CMD ["node", "src/server.js"]
