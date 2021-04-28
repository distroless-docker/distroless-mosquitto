FROM alpine:3.10 AS build

LABEL description="Scratch Eclipse Mosquitto MQTT Broker"

ENV VERSION=2.0.10 \
    DOWNLOAD_SHA256=0188f7b21b91d6d80e992b8d6116ba851468b3bd154030e8a003ed28fb6f4a44 \
    GPG_KEYS=A0D6EEA1DCAE49A635A3B2F0779B22DFB3E717B7 \
    LWS_VERSION=2.4.2 \
    LWS_SHA256=73012d7fcf428dedccc816e83a63a01462e27819d5537b8e0d0c7264bfacfad6 \
    CJSON_VERSION=1.7.14 \
    CJSON_SHA256=fb50a663eefdc76bafa80c82bc045af13b1363e8f45cec8b442007aef6a41343

RUN set -x && \
    echo "Running on $(uname -m)" && \
    apk --no-cache add --virtual build-deps \
        build-base \
        cmake \
        gnupg \
        util-linux-dev
RUN wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz -O /tmp/mosq.tar.gz && \
    echo "$DOWNLOAD_SHA256  /tmp/mosq.tar.gz" | sha256sum -c - && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz.asc -O /tmp/mosq.tar.gz.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $GPG_KEYS from $server"; \
        gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    gpg --batch --verify /tmp/mosq.tar.gz.asc /tmp/mosq.tar.gz && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" /tmp/mosq.tar.gz.asc && \
    mkdir -p /build/mosq && \
    tar --strip=1 -xf /tmp/mosq.tar.gz -C /build/mosq && \
    rm /tmp/mosq.tar.gz && \
    make -C /build/mosq -j "$(nproc)" \
        CFLAGS="-Wall -O2 -I/build" \
        WITH_ADNS=no \
        WITH_TLS=no \
        WITH_TLS_PSK=no \
        WITH_DOCS=no \
        WITH_SHARED_LIBRARIES=no \
        WITH_STATIC_LIBRARIES=yes \
        WITH_SRV=no \
        WITH_STRIP=yes \
        WITH_CJSON=no \
        WITH_WEBSOCKETS=no \
        prefix=/usr \
        binary && \
    addgroup -S -g 1883 mosquitto 2>/dev/null && \
    adduser -S -u 1883 -D -H -h /var/empty -s /sbin/nologin -G mosquitto -g mosquitto mosquitto 2>/dev/null && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log /mosquitto/licenses && \
    install -d /usr/sbin/ && \
    install -s -m755 /build/mosq/client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 /build/mosq/client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 /build/mosq/client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m755 /build/mosq/src/mosquitto /usr/sbin/mosquitto && \
    install -m644 /build/mosq/mosquitto.conf /mosquitto/config/mosquitto.conf && \
    install -m644 /build/mosq/LICENSE.txt /mosquitto/licenses/LICENSE.txt && \
    install -m644 /build/mosq/edl-v10 /mosquitto/licenses/edl-v10 && \
    install -m644 /build/mosq/epl-v20 /mosquitto/licenses/epl-v20 && \
    cat /mosquitto/licenses/LICENSE.txt >> /mosquitto/licenses/mosquitto-${VERSION} && \
    cat /mosquitto/licenses/edl-v10 >> /mosquitto/licenses/mosquitto-${VERSION} && \
    cat /mosquitto/licenses/epl-v20 >> /mosquitto/licenses/mosquitto-${VERSION} && \
    chown -R mosquitto:mosquitto /mosquitto && \
    apk del build-deps && \
    rm -rf /build
    
VOLUME ["/mosquitto/data", "/mosquitto/log"]

COPY mosquitto-no-auth.conf /

FROM scratch AS mosqfinal
COPY --from=build mosquitto-no-auth.conf /
COPY --from=build /etc/passwd /etc/
COPY --from=build /etc/group /etc/
COPY --from=build /usr/sbin/mosquitto /usr/sbin/
COPY --from=build /lib/ld-musl-*.so.1 /lib/
COPY --from=build /lib/libc.musl-*.so.1 /lib/
# copy license texts
COPY --from=build /mosquitto/licenses/* /licenses/

EXPOSE 1883
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto-no-auth.conf"]
