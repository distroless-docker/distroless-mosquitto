FROM alpine:3.12 AS build

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
    apk add --virtual build-deps \
        build-base \
        libressl-dev \
        bash \
        su-exec \
        go \
        cmake \
        make \
        gnupg \
        musl-dev \
        linux-headers \
        util-linux-dev
RUN mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log /mosquitto/licenses && \
    wget https://github.com/warmcat/libwebsockets/archive/v${LWS_VERSION}.tar.gz -O /tmp/lws.tar.gz && \
    echo "$LWS_SHA256  /tmp/lws.tar.gz" | sha256sum -c - && \
    mkdir -p /build/lws && \
    tar --strip=1 -xf /tmp/lws.tar.gz -C /build/lws && \
    rm /tmp/lws.tar.gz && \
    cd /build/lws && \
    cat ./LICENSE >> /mosquitto/licenses/libwebsockets-${LWS_VERSION} && \
    cmake . \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DLWS_IPV6=ON \
        -DLWS_WITHOUT_BUILTIN_GETIFADDRS=ON \
        -DLWS_WITHOUT_CLIENT=ON \
        -DLWS_WITHOUT_EXTENSIONS=ON \
        -DLWS_WITHOUT_TESTAPPS=ON \
        -DLWS_WITH_SHARED=OFF \
        -DLWS_WITH_ZIP_FOPS=OFF \
        -DLWS_WITH_ZLIB=OFF && \
    make -j "$(nproc)" && \
    rm -rf /root/.cmake && \
    wget https://github.com/DaveGamble/cJSON/archive/v${CJSON_VERSION}.tar.gz -O /tmp/cjson.tar.gz && \
    echo "$CJSON_SHA256  /tmp/cjson.tar.gz" | sha256sum -c - && \
    mkdir -p /build/cjson && \
    tar --strip=1 -xf /tmp/cjson.tar.gz -C /build/cjson && \
    rm /tmp/cjson.tar.gz && \
    cd /build/cjson && \
    cat ./LICENSE >> /mosquitto/licenses/cJSON-${CJSON_VERSION} && \
    cmake . \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DBUILD_SHARED_AND_STATIC_LIBS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCJSON_BUILD_SHARED_LIBS=OFF \
        -DCJSON_OVERRIDE_BUILD_SHARED_LIBS=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr && \
    make -j "$(nproc)" && \
    rm -rf /root/.cmake && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz -O /tmp/mosq.tar.gz && \
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
        CFLAGS="-Wall -O2 -I/build/lws/include -I/build" \
        LDFLAGS="-L/build/lws/lib -L/build/cjson" \
        WITH_ADNS=no \
        WITH_TLS=yes \
        WITH_TLS_PSK=no \
        WITH_DOCS=no \
        WITH_SHARED_LIBRARIES=yes \
        # WITH_STATIC_LIBRARIES=yes \
        WITH_SRV=no \
        WITH_STRIP=yes \
        WITH_CJSON=yes \
        WITH_WEBSOCKETS=yes \
        prefix=/usr \
        binary && \
    addgroup -S -g 1883 mosquitto 2>/dev/null && \
    adduser -S -u 1883 -D -H -h /var/empty -s /sbin/nologin -G mosquitto -g mosquitto mosquitto 2>/dev/null && \
    install -d /usr/sbin/ && \
    install -s -m755 /build/mosq/client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 /build/mosq/client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 /build/mosq/client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m755 /build/mosq/apps/mosquitto_ctrl/mosquitto_ctrl /usr/bin/mosquitto_ctrl && \
    install -s -m755 /build/mosq/apps/mosquitto_passwd/mosquitto_passwd /usr/bin/mosquitto_passwd && \
    install -s -m755 /build/mosq/src/mosquitto /usr/sbin/mosquitto && \
    install -s -m755 /build/mosq/plugins/dynamic-security/mosquitto_dynamic_security.so /usr/lib/mosquitto_dynamic_security.so && \
    install -s -m644 /build/mosq/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1 && \
    install -m644 /build/mosq/mosquitto.conf /mosquitto/config/mosquitto.conf && \
    install -m644 /build/mosq/LICENSE.txt /mosquitto/licenses/LICENSE.txt && \
    install -m644 /build/mosq/edl-v10 /mosquitto/licenses/edl-v10 && \
    install -m644 /build/mosq/epl-v20 /mosquitto/licenses/epl-v20 && \
    cat /mosquitto/licenses/LICENSE.txt >> /mosquitto/licenses/mosquitto-${VERSION} && \
    cat /mosquitto/licenses/edl-v10 >> /mosquitto/licenses/mosquitto-${VERSION} && \
    cat /mosquitto/licenses/epl-v20 >> /mosquitto/licenses/mosquitto-${VERSION} && \
    chown -R mosquitto:mosquitto /mosquitto && \
    apk --no-cache add ca-certificates libressl && \
    # apk del build-deps && \
    rm -rf /build
    
# COPY docker-entrypoint.sh mosquitto-no-auth.conf /
COPY mosquitto-no-auth.conf /

WORKDIR /build-entrypoint
COPY ./docker-scratch-entrypoint/* /build-entrypoint/
RUN cd /build-entrypoint && \
    CGO_ENABLED=0 go build docker-scratch-entrypoint.go

# RUN mkdir -p /etc/mosquitto && chown -R mosquitto:mosquitto /etc/mosquitto && ls -la /etc

# Build toybox (currently not used but may be useful for developers)
# https://github.com/landley/toybox/releases
#WORKDIR /toybox
#ENV TOYBOX_VERSION 0.8.4
#RUN set -eux; \
#	wget -O toybox.tgz "https://landley.net/toybox/downloads/toybox-${TOYBOX_VERSION}.tar.gz"; \
#	tar -xf toybox.tgz --strip-components=1; \
#	rm toybox.tgz
#RUN make root BUILTIN=1

RUN mkdir /libressl && \
    cd /libressl && \
    apk fetch libressl3.1-libssl && \
    apk fetch libressl3.1-libcrypto && \
    apk fetch libressl3.1-libtls && \
    apk fetch musl && \
    ls *.apk | xargs -n1 tar xf && \
    rm .PKGINFO .SIGN.RSA.* *.apk

RUN mkdir /libressl-doc && \
    cd /libressl-doc && \
    apk fetch libressl-doc && \
    ls *.apk | xargs -n1 tar xf && \
    rm .PKGINFO .SIGN.RSA.* *.apk && \
    cp /libressl-doc/usr/share/licenses/libressl/COPYING /mosquitto/licenses/libressl-3.1 && \
    chown mosquitto:mosquitto /mosquitto/licenses/*

# --------------------------------------------
# Create image with ToyBox and Mosquitto
# --------------------------------------------

FROM scratch AS mosqtmp

# toybox (currently not used but may be useful for developers)
# COPY --from=build /toybox/root/host/fs/ /

# libressl libs & licence
COPY --from=build /libressl/ /

# mosquitto
# COPY --from=build docker-entrypoint.sh /
COPY --from=build mosquitto-no-auth.conf /
COPY --from=build /etc/passwd /etc/
COPY --from=build /etc/group /etc/
# COPY --from=build /sbin/su-exec /sbin/
COPY --from=build /usr/sbin/mosquitto /usr/sbin/
COPY --from=build /usr/bin/mosquitto_pub /usr/bin/
COPY --from=build /usr/bin/mosquitto_sub /usr/bin/
COPY --from=build /usr/bin/mosquitto_rr /usr/bin/
COPY --from=build /usr/bin/mosquitto_ctrl /usr/bin/
COPY --from=build /usr/bin/mosquitto_passwd /usr/bin/
COPY --from=build /usr/lib/mosquitto_dynamic_security.so /usr/lib/
COPY --from=build /usr/lib/libmosquitto.so.1 /usr/lib/
COPY --from=build /mosquitto/config/mosquitto.conf /mosquitto/config/

# copy license texts
COPY --from=build /mosquitto/licenses/* /licenses/

# copy our entrypoint "replacement"
COPY --from=build /build-entrypoint/docker-scratch-entrypoint /docker-scratch-entrypoint
# COPY --from=build /usr/bin/ldd /usr/bin/

FROM scratch AS mosqfinal
COPY --from=mosqtmp / /
#COPY --from=build --chown=1883:1883 /mosquitto /mosquitto

EXPOSE 1883

VOLUME ["/mosquitto/data", "/mosquitto/log"]
ENTRYPOINT ["/docker-scratch-entrypoint"]
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
# CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto-no-auth.conf"]
