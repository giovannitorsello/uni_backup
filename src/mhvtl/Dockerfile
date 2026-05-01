# ================================================================
# mhvtl — Virtual Tape Library
# Richiede kernel headers dell'host montati in /usr/src
# e modalità privileged per caricare il modulo kernel
# ================================================================
FROM debian:trixie AS mhvtl

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        linux-headers-generic \
        mtx \
        lsscsi \
        sg3-utils \
        lzma-dev \
        zlib1g-dev \
        libzstd-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/markh794/mhvtl.git /build/mhvtl

WORKDIR /build/mhvtl

RUN make && make install

COPY entrypoint-mhvtl.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]