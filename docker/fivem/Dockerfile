ARG FIVEM_NUM=35245
ARG FIVEM_VER=35245-6efb47dff473c0e2a12fb50b08d74c0eb24a50d5
ARG DATA_VER=0e7ba538339f7c1c26d0e689aa750a336576cf02

FROM spritsail/alpine:3.23 AS builder

ARG FIVEM_VER
ARG DATA_VER

WORKDIR /output

RUN wget -O- https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FIVEM_VER}/fx.tar.xz \
        | tar xJ --strip-components=1 \
            --exclude alpine/dev --exclude alpine/proc \
            --exclude alpine/run --exclude alpine/sys \
 && mkdir -p /output/opt/cfx-server-data /output/usr/local/share \
 && wget -O- https://github.com/citizenfx/cfx-server-data/archive/${DATA_VER}.tar.gz \
        | tar xz --strip-components=1 -C opt/cfx-server-data

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
RUN apk add --no-cache tini

COPY entrypoint.sh /usr/local/bin/sunset-entrypoint.sh
RUN chmod +x /usr/local/bin/sunset-entrypoint.sh

WORKDIR /config
EXPOSE 30120

CMD [""]

ENTRYPOINT ["/usr/local/bin/sunset-entrypoint.sh"]
