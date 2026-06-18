FROM alpine:3.23

LABEL maintainer="hareesh"

ENV NGINX_VERSION  1.30.2
ENV PKG_RELEASE    1
ENV DYNPKG_RELEASE 1
ENV UID 1010
RUN set -x \
    && addgroup -g $UID -S nginx \
    && adduser -S -D -H -u $UID -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages="nginx=${NGINX_VERSION}-r${PKG_RELEASE}" && \
    mkdir -p /var/cache/nginx /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp /var/run/nginx /var/log/nginx; \
    touch /var/run/nginx.pid && chown -R nginx:nginx /var/cache/nginx /var/run/nginx /var/log/nginx /var/run/nginx.pid \ 
    && apk add --no-cache --virtual .checksum-deps openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
            set -x \
            && KEY_SHA512="e09fa32f0a0eab2b879ccbbc4d0e4fb9751486eedda75e35fac65802cc9faa266425edf83e261137a2f4d16281ce2c1a5f4502930fe75154723da014214f0655" \
            && wget -O /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub \
            && if echo "$KEY_SHA512 */tmp/nginx_signing.rsa.pub" | sha512sum -c -; then \
                echo "key verification succeeded!"; \
                mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/; \
            else \
                echo "key verification failed!"; \
                exit 1; \
            fi \
            && DEPS=$(apk query --summarize depends --recursive --no-cache \
                       --repository "@nginxorg https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" \
                       ${nginxPackages/=/@nginxorg=}) \
            && apk add --no-cache $DEPS \
            && apk add --repositories-file /dev/null -X "https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre2-dev \
                zlib-dev \
                linux-headers \
                bash \
                alpine-sdk \
                findutils \
                curl \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/60789259bfab36b1669a414881a9d002fd246d6b.tar.gz \
                && PKGOSSCHECKSUM=\"9282a0265c921af3e2d5760cbdc06aae65e6efb145ed266fe02102326174a9e9405f6492979372556c14e2f4f8cf66a48c338d054d0ece375a1c41f343f244cc *60789259bfab36b1669a414881a9d002fd246d6b.tar.gz\" \
                && if [ \"\$(openssl sha512 -r 60789259bfab36b1669a414881a9d002fd246d6b.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf 60789259bfab36b1669a414881a9d002fd246d6b.tar.gz \
                && cd pkg-oss-60789259bfab36b1669a414881a9d002fd246d6b \
                && cd alpine \
                && make base \
                && apk index --allow-untrusted -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && DEPS=$(apk query --summarize depends --recursive --no-cache \
                       --repository "@nginxorg ${tempDir}/packages/alpine/" \
                       ${nginxPackages/=/@nginxorg=}) \
            && apk add --no-cache $DEPS \
            && apk add --repositories-file /dev/null -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
    && apk del --no-network .checksum-deps \
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && mkdir /docker-entrypoint.d \
    && sed -i 's/^user .*/# user disabled for non-root/' /etc/nginx/nginx.conf

COPY --chown=nginx:0 --chmod=0775 src/ /docker-entrypoint.d/
COPY --chown=nginx:0 --chmod=0775 ./nginx.conf /etc/nginx/nginx.conf
RUN mv /docker-entrypoint.d/docker-entrypoint.sh / && \
    apk update --no-cache && \
    apk upgrade --no-cache && \
    apk --no-cache add  \
    binutils-gold \ 
    libstdc++ \
    g++ \
    gnupg \
    libgcc \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    bash \
    alpine-sdk \
    findutils \
    curl \
    traceroute \
    busybox-extras \
    ca-certificates \
    gettext-envsubst \
    tzdata \
    && update-ca-certificates && rm -rf /tmp/*
ENTRYPOINT ["/docker-entrypoint.sh"]

STOPSIGNAL SIGQUIT
USER $UID
CMD ["nginx", "-g", "daemon off;"]