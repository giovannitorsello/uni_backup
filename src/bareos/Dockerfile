# ================================================================
# UEB — Bareos build from LOCAL source on Debian 13 (trixie)
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
#   base      → runtime Debian 13 condiviso
#   director  → Director daemon + bconsole  (~150 MB)
#   storage   → Storage daemon              (~80  MB)
#   client    → File daemon                 (~60  MB)
#   webui     → Bareos WebUI (Apache + PHP) (~120 MB)
# ================================================================

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=12

# ----------------------------------------------------------------
# base — runtime Debian 13 condiviso tra director/storage/client
# ----------------------------------------------------------------
FROM debian:trixie AS base

ARG DEBIAN_FRONTEND=noninteractive

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

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        ninja-build \
        pkg-config \
        git \
        # Compressione
        liblzo2-dev \
        liblz4-dev \
        libzstd-dev \
        zlib1g-dev \
        libbz2-dev \
        # Database (PostgreSQL)
        libpq-dev \
        postgresql-client \
        postgresql \
        # Sicurezza e sistema
        libssl-dev \
        libacl1-dev \
        libcap-dev \
        libpam0g-dev \
        libtirpc-dev \
        # Interfaccia e console
        libreadline-dev \
        libcdk5-dev \
        libncurses5-dev \
        # JSON (obbligatorio Bareos 25+)
        libjansson-dev \
        # Test e scripting
        libgtest-dev \
        libgmock-dev \
        googletest \
        python3-dev \
        python3-setuptools \
        # Strumenti richiesti dagli script Bareos
        bc \
        lsof \
        psmisc \
        # Runtime WebUI (necessario per make install della webui)
        apache2 \
        php \
        php-bcmath \
        php-curl \
        php-mbstring \
        php-xml \
        php-zip \
        libapache2-mod-php \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Sorgenti locali (già clonati con: make clone-bareos)
# Il contesto di build è docker/bareos/ — i sorgenti sono in
# docker/bareos/bareos-src/
COPY bareos-src/ /build/bareos-src/

RUN cmake \
    -DENABLE_WERROR=OFF \
    -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized" \
    -S /build/bareos-src \
    -B /build/cmake-build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -Dconfdir=/etc/bareos \
    -DDEFAULT_WORKING_DIR=/var/lib/bareos \
    -DDEFAULT_PIDDIR=/run/bareos \
    -DDB_POSTGRESQL=ON \
    -DENABLE_WEBUI=ON \
    -DMYSQL=OFF \
    -Dsqlite3=OFF \
    -DPYTHON_PLUGINS=ON \
    -Dtraymonitor=OFF \
    -Dbuild-unittests=OFF \
    -Dbuild-systemtests=OFF

RUN cmake --build /build/cmake-build -j${BUILD_JOBS}

RUN DESTDIR=/bareos-install cmake --install /build/cmake-build

# Verifica binari fondamentali
RUN ls /bareos-install/usr/sbin/bareos-dir \
       /bareos-install/usr/sbin/bareos-sd \
       /bareos-install/usr/sbin/bareos-fd \
       /bareos-install/usr/sbin/bconsole \
       /bareos-install/usr/share/bareos-webui \
 && echo "==> Binari e WebUI Bareos compilati con successo"

# ----------------------------------------------------------------
# director — Bareos Director daemon + bconsole
# ----------------------------------------------------------------
FROM base AS director

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libpam0g \
        postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /bareos-install/ /

COPY templates/bareos-dir.conf.tpl     /etc/bareos/templates/bareos-dir.conf.tpl
COPY templates/bareos-console.conf.tpl /etc/bareos/templates/bareos-console.conf.tpl

COPY entriespoint/entrypoint-dir.sh /entrypoint.sh
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

COPY templates/bareos-sd.conf.tpl /etc/bareos/templates/bareos-sd.conf.tpl
# stage storage
COPY config/bareos-sd/device/ /etc/bareos/bareos-sd.d/device/

COPY entriespoint/entrypoint-sd.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9103
ENTRYPOINT ["/entrypoint.sh"]

# ----------------------------------------------------------------
# client — Bareos File Daemon
# ----------------------------------------------------------------
FROM base AS client

# FIX: *.conf.tpl va nella directory, non in un singolo file
COPY --from=builder /bareos-install/ /

COPY templates/bareos-fd.conf.tpl /etc/bareos/templates/bareos-fd.conf.tpl

COPY entriespoint/entrypoint-fd.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9102
ENTRYPOINT ["/entrypoint.sh"]

# ----------------------------------------------------------------
# webui — Bareos WebUI (Apache + PHP, compilata nello stage builder)
# ----------------------------------------------------------------
FROM debian:trixie AS webui

ARG DEBIAN_FRONTEND=noninteractive

# Solo runtime Apache + PHP — niente compilatori
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        php \
        php-bcmath \
        php-curl \
        php-mbstring \
        php-xml \
        php-zip \
        libapache2-mod-php \
        gettext-base \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Copia WebUI e configurazione Apache dal builder
COPY --from=builder /bareos-install/usr/share/bareos-webui  /usr/share/bareos-webui
COPY --from=builder /bareos-install/etc/bareos-webui        /etc/bareos-webui
COPY --from=builder \
    /bareos-install/etc/apache2/conf-available/bareos-webui.conf \
    /etc/apache2/conf-available/bareos-webui.conf

RUN a2enconf bareos-webui \
 && ln -sf /dev/stdout /var/log/apache2/access.log \
 && ln -sf /dev/stderr /var/log/apache2/error.log

# directors.ini montato via volume nel compose:
# contiene host/porta/password del Director e cambia per environment
VOLUME ["/etc/bareos-webui"]

EXPOSE 80
CMD ["apache2ctl", "-D", "FOREGROUND"]