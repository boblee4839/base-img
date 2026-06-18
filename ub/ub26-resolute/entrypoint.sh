#!/usr/bin/env bash
set -e

TMPDIR=${TMPDIR:-/tmp}

JRE_CACERTS_PATH=$JAVA_HOME/lib/security/cacerts

if [ -n "$USE_SYSTEM_CA_CERTS" ]; then

    if [ ! -w "$TMPDIR" ]; then
        echo "Using additional CA certificates requires write permissions to $TMPDIR. Cannot create truststore."
        exit 1
    fi
    if [ ! -w "$JRE_CACERTS_PATH" ]; then
        JRE_CACERTS_PATH_NEW=$(mktemp)
        echo "Using a temporary truststore at $JRE_CACERTS_PATH_NEW"
        cp "$JRE_CACERTS_PATH" "$JRE_CACERTS_PATH_NEW"
        JRE_CACERTS_PATH=$JRE_CACERTS_PATH_NEW
        export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -Djavax.net.ssl.trustStore=${JRE_CACERTS_PATH} -Djavax.net.ssl.trustStorePassword=changeit"
    fi

    tmp_store=$(mktemp)
    trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$tmp_store" > /dev/null

    keytool -importkeystore -destkeystore "$JRE_CACERTS_PATH" -srckeystore "$tmp_store" -srcstorepass changeit -deststorepass changeit -noprompt > /dev/null
    rm -f "$tmp_store"
    for i in /certificates/*crt; do
        if [ ! -f "$i" ]; then
            continue
        fi
        tmp_dir=$(mktemp -d)
        BASENAME=$(basename "$i" .crt)
        csplit -s -z -b %02d.crt -f "$tmp_dir/$BASENAME-" "$i" '/-----BEGIN CERTIFICATE-----/' '{*}'

        for crt in "$tmp_dir/$BASENAME"-*; do
            CN=$(openssl x509 -in "$crt" -noout -subject -nameopt -space_eq | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')
            SERIAL=$(openssl x509 -in "$crt" -noout -serial | sed -n 's/^serial=\(.*\)$/\1/p')
            
            ALIAS=$CN
            if keytool -list -keystore "$JRE_CACERTS_PATH" -storepass changeit -alias "$ALIAS" >/dev/null 2>&1; then
                ALIAS="${CN}_${SERIAL}"
            fi

            echo "Adding certificate with alias $ALIAS to the JVM truststore"

            keytool -import -noprompt -alias "$ALIAS" -file "$crt" -keystore "$JRE_CACERTS_PATH" -storepass changeit >/dev/null
        done
    done
    if [ "$(id -u)" -eq 0 ]; then
        if [ -d /certificates ] && [ "$(ls -A /certificates 2>/dev/null)" ]; then
            cp -La /certificates/* /usr/local/share/ca-certificates/
        fi
        update-ca-certificates
    else
        true
    fi
fi

export JRE_CACERTS_PATH

exec "$@"