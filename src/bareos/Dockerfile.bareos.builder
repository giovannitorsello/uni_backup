# Immagine: bareos-builder:latest
FROM bareos-base:latest

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_JOBS=12

WORKDIR /build
COPY bareos-src/ /build/bareos-src/

RUN cmake -S /build/bareos-src -B /build/cmake-build -G Ninja \
    -DENABLE_WERROR=OFF \
    -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized -Wno-restrict" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -Dconfdir=/etc/bareos \
    -DDEFAULT_WORKING_DIR=/var/lib/bareos \
    -DDEFAULT_PIDDIR=/run/bareos \
    -DDB_POSTGRESQL=ON \
    -DENABLE_WEBUI=ON \
    -DPYTHON_PLUGINS=ON \
    -Dbuild-unittests=OFF \
    -Dbuild-systemtests=OFF \
    -DENABLE_SYSTEMTESTS=OFF \
    -DMYSQL=OFF \
    -Dsqlite3=OFF \
    -Dtraymonitor=OFF \
     && cmake --build /build/cmake-build -j${BUILD_JOBS} \
     && DESTDIR=/bareos-install cmake --install /build/cmake-build
