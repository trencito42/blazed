ARG FIVEM_NUM=35245
ARG FIVEM_VER=35245-6efb47dff473c0e2a12fb50b08d74c0eb24a50d5
ARG DATA_VER=0e7ba538339f7c1c26d0e689aa750a336576cf02
ARG OX_LIB_VER=3.39.0
ARG PMA_VOICE_SHA=6c9d96ed7a02e30912f1a0ce92629bf9afbbca8c
ARG BOB74_IPL_VER=2.7.0

FROM spritsail/alpine:3.23 AS builder

ARG FIVEM_VER
ARG DATA_VER
ARG OX_LIB_VER
ARG PMA_VOICE_SHA
ARG BOB74_IPL_VER

WORKDIR /output

RUN apk add --no-cache unzip \
 && wget -O- https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FIVEM_VER}/fx.tar.xz \
        | tar xJ --strip-components=1 \
            --exclude alpine/dev --exclude alpine/proc \
            --exclude alpine/run --exclude alpine/sys \
 && mkdir -p /output/opt/cfx-server-data /output/usr/local/share \
 && wget -O- https://github.com/citizenfx/cfx-server-data/archive/${DATA_VER}.tar.gz \
        | tar xz --strip-components=1 -C opt/cfx-server-data

# Pin runtime dependencies in the image. Production must not depend on stale
# copies surviving in the persistent /config volume.
RUN mkdir -p /output/opt/cfx-server-data/resources \
 && wget -O /tmp/ox_lib.zip https://github.com/overextended/ox_lib/releases/download/v${OX_LIB_VER}/ox_lib.zip \
 && unzip -q /tmp/ox_lib.zip -d /output/opt/cfx-server-data/resources \
 && mkdir -p /output/opt/cfx-server-data/resources/pma-voice \
 && wget -O- https://github.com/AvarianKnight/pma-voice/archive/${PMA_VOICE_SHA}.tar.gz \
      | tar xz --strip-components=1 -C /output/opt/cfx-server-data/resources/pma-voice \
 && mkdir -p /output/opt/cfx-server-data/resources/bob74_ipl \
 && wget -O- https://github.com/Bob74/bob74_ipl/archive/refs/tags/${BOB74_IPL_VER}.tar.gz \
      | tar xz --strip-components=1 -C /output/opt/cfx-server-data/resources/bob74_ipl \
 && rm -f /tmp/ox_lib.zip

COPY default-server.cfg opt/cfx-server-data/server.cfg
COPY spritsail-entrypoint usr/bin/entrypoint

RUN chmod +x /output/usr/bin/entrypoint

#================

FROM scratch

ARG FIVEM_VER
ARG FIVEM_NUM
ARG DATA_VER

LABEL org.opencontainers.image.authors="Spritsail <fivem@spritsail.io>" \
      org.opencontainers.image.vendor="SunsetMP" \
      org.opencontainers.image.title="FiveM" \
      org.opencontainers.image.version=${FIVEM_NUM} \
      io.spritsail.version.fivem=${FIVEM_VER} \
      io.spritsail.version.fivem_data=${DATA_VER}

COPY --from=builder /output/ /
RUN apk add --no-cache tini mariadb-client

COPY entrypoint.sh /usr/local/bin/sunset-entrypoint.sh
RUN chmod +x /usr/local/bin/sunset-entrypoint.sh

WORKDIR /config
EXPOSE 30120

CMD [""]

ENTRYPOINT ["/usr/local/bin/sunset-entrypoint.sh"]
