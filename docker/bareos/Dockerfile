# ================================================================
# TapeGuard — Bareos build from LOCAL source on Debian 13 (trixie)
#
# PREREQUISITO: eseguire prima  ->  make clone-bareos
# Il clone locale in docker/bareos/bareos-src/ viene copiato
# nell'immagine: nessun accesso internet durante il build.
#
# AVVERTENZA: la compilazione richiede 20-60 minuti a seconda
# delle risorse della macchina host. Usare BUILD_JOBS per
# parallelizzare (default: 4).
#
# Stages:
#   builder   → compila tutto (pesante, ~2 GB)
#   director  → solo il Director daemon + bconsole (~150 MB)
#   storage   → solo lo Storage daemon               (~80 MB)
#   client    → solo il File daemon                  (~60 MB)
# ================================================================

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=12

# ----------------------------------------------------------------
# base — runtime Debian 13 condiviso tra director/storage/client
# ----------------------------------------------------------------
FROM debian:trixie AS base

ARG DEBIAN_FRONTEND=noninteractive

# Dipendenze runtime comuni (senza -dev)
# Nota: Debian 13 usa il suffisso t64 per alcune lib (es. libssl3t64)
# apt risolve automaticamente il nome corretto
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gettext-base \
    libacl1 \
    libcap2 \
    libjansson4 \
    liblz4-1 \
    libreadline8 \
    libzstd1 \
    && apt-get install -y --no-install-recommends libssl3 2>/dev/null \
    || apt-get install -y --no-install-recommends libssl3t64 \
    && rm -rf /var/lib/apt/lists/*

# Crea utente e gruppo bareos
RUN groupadd -r bareos \
 && useradd -r -g bareos -d /var/lib/bareos -s /bin/false bareos \
 && mkdir -p \
      /etc/bareos \
      /etc/bareos/templates \
      /etc/bareos/bareos-dir.d \
      /var/lib/bareos \
      /var/lib/bareos/storage \
      /var/log/bareos \
      /run/bareos \
 && chown -R bareos:bareos \
      /etc/bareos \
      /var/lib/bareos \
      /var/log/bareos \
      /run/bareos

# ----------------------------------------------------------------
# builder — compila Bareos dai sorgenti locali
# ----------------------------------------------------------------
FROM debian:trixie AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=12

# Dipendenze di compilazione
# Dipendenze di compilazione per Bareos su Debian 13
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    ninja-build \
    pkg-config \
    git \
    # Compressione (LZO, LZ4 e ZSTD sono tutti usati da Bareos)
    liblzo2-dev \
    liblz4-dev \
    libzstd-dev \
    zlib1g-dev \
    libbz2-dev \
    # Database (PostgreSQL)
    # Installiamo 'postgresql' per avere pg_ctl (richiesto dai systemtests)
    libpq-dev \
    postgresql-client \
    postgresql \
    # Sicurezza e Sistema
    libssl-dev \
    libacl1-dev \
    libcap-dev \
    libpam0g-dev \
    libtirpc-dev \
    # Interfaccia e Console
    libreadline-dev \
    libcdk5-dev \
    libncurses5-dev \
    # JSON e Strutture dati (Obbligatori per Bareos 25+)
    libjansson-dev \
    # Test e Scripting
    libgtest-dev \
    python3-dev \
    python3-setuptools \
    # Strumenti richiesti dagli script di configurazione Bareos
    bc \
    lsof \
    psmisc \
    libgmock-dev \
    googletest \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build

# ---------------------------------------------------------------
# COPY sorgenti locali (già clonati con: make clone-bareos)
# Il contesto di build è docker/bareos/ — i sorgenti sono in
# docker/bareos/bareos-src/
# ---------------------------------------------------------------
COPY bareos-src/ /build/bareos-src/


#RUN mkdir /build/build-docs
#RUN cd /build/build-docs

#RUN cmake -Ddocs-only=yes  /build/bareos-src
#RUN make


# Stampa la versione clonata per tracciabilità nel build log
#RUN echo "==> Sorgente Bareos:" \
# && git -C /build/bareos-src describe --tags --always --long 2>/dev/null \
#    || cat /build/bareos-src/VERSION 2>/dev/null \
#    || echo "(versione non determinabile)"

# RUN git -C /build/bareos-src switch bareos-25
# Configura con CMake
# - CMAKE_INSTALL_PREFIX=/usr  → i binari vanno in /usr/sbin ecc.
# - DESTDIR=/bareos-install    → staging per COPY nelle fasi runtime
# - postgresql=ON              → catalogo PostgreSQL
# - mysql=OFF, sqlite3=OFF     → non servono
# - python-plugins=OFF         → riduce dipendenze

RUN cmake \        
    -S /build/bareos-src \
    -B /build/cmake-build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -Dconfdir=/etc/bareos \
    -DDEFAULT_WORKING_DIR=/var/lib/bareos \
    -DDEFAULT_PIDDIR=/run/bareos \
    -DDB_POSTGRESQL=ON \
    -DMYSQL=OFF \
    -Dsqlite3=OFF \
    -DPYTHON_PLUGINS=ON \
    -Dtraymonitor=OFF \
    -Dbuild-unittests=OFF \
    -Dbuild-systemtests=OFF

# Compilazione
RUN cmake --build /build/cmake-build -j${BUILD_JOBS}

# Installazione in staging (DESTDIR + prefix = /bareos-install/usr/...)
RUN DESTDIR=/bareos-install cmake --install /build/cmake-build

# Verifica binari fondamentali
RUN ls /bareos-install/usr/sbin/bareos-dir \
       /bareos-install/usr/sbin/bareos-sd \
       /bareos-install/usr/sbin/bareos-fd \
       /bareos-install/usr/sbin/bconsole \
 && echo "==> Binari Bareos compilati con successo"

# ----------------------------------------------------------------
# director — Bareos Director daemon + bconsole
# ----------------------------------------------------------------
FROM base AS director

ARG DEBIAN_FRONTEND=noninteractive

# Dipendenze extra solo per il Director
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libpam0g \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copia i file compilati dallo staging
COPY --from=builder /bareos-install/ /

# Copia il template di configurazione
COPY bareos-dir.conf.tpl   /etc/bareos/templates/bareos-dir.conf.tpl
COPY bareos-console.conf.tpl /etc/bareos/templates/bareos-console.conf.tpl

# Entrypoint
COPY entrypoint-dir.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9101
ENTRYPOINT ["/entrypoint.sh"]

# ----------------------------------------------------------------
# storage — Bareos Storage Daemon
# ----------------------------------------------------------------
FROM base AS storage

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    mtx \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /bareos-install/ /

COPY bareos-sd.conf.tpl /etc/bareos/templates/bareos-sd.conf.tpl

COPY entrypoint-sd.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9103
ENTRYPOINT ["/entrypoint.sh"]

# ----------------------------------------------------------------
# client — Bareos File Daemon (installabile anche sui clienti)
# ----------------------------------------------------------------
FROM base AS client

COPY --from=builder /bareos-install/ /

COPY bareos-fd.conf.tpl /etc/bareos/templates/bareos-fd.conf.tpl

COPY entrypoint-fd.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9102
ENTRYPOINT ["/entrypoint.sh"]
