FROM debian:trixie-slim

ENV LANG=C.UTF-8
ENV JAVA_HOME=/opt/java/openjdk
ENV MAVEN_HOME=/opt/maven
ENV MAVEN_VERSION=3.9.16
ARG MAVEN_DOWNLOAD_SHA512="831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6"
ENV PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

# Temurin repo + version
ENV TEMURIN_REPO="adoptium/temurin21-binaries"
ENV TEMURIN_TAG="jdk-21.0.12%2B8"
ENV TEMURIN_VERSION="21.0.12_8"
ENV TEMURIN_MAJOR="OpenJDK21U"
ENV TEMURIN_TYPE="jdk"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        fontconfig \
        fonts-noto-core \
        ca-certificates ca-certificates-java \
        libsecret-1-0 libsecret-1-dev libxml2 libgsf-1-114 \
        p11-kit \
        tzdata \
        curl openssl \
        bash traceroute net-tools wget jq && \
    rm -rf /var/lib/apt/lists/*

#
# === Multi‑Arch JDK Download + SHA256 Validation ===
#
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
        amd64)   ASSET_SUFFIX="x64_linux_hotspot" ;; \
        arm64)   ASSET_SUFFIX="aarch64_linux_hotspot" ;; \
        *) echo "Unsupported arch: ${ARCH}"; exit 1 ;; \
    esac; \
    \
    API_URL="https://api.github.com/repos/${TEMURIN_REPO}/releases/tags/${TEMURIN_TAG}"; \
    curl -sL "$API_URL" -o /tmp/release.json; \
    \
    ASSET_NAME="${TEMURIN_MAJOR}-${TEMURIN_TYPE}_${ASSET_SUFFIX}_${TEMURIN_VERSION}.tar.gz"; \
    SHA_NAME="${ASSET_NAME}.sha256.txt"; \
    \
    ASSET_URL=$(jq -r --arg A "$ASSET_NAME" '.assets[] | select(.name==$A) | .browser_download_url' /tmp/release.json); \
    SHA_URL=$(jq -r --arg S "$SHA_NAME" '.assets[] | select(.name==$S) | .browser_download_url' /tmp/release.json); \
    \
    curl -sL "$ASSET_URL" -o /tmp/openjdk.tar.gz; \
    curl -sL "$SHA_URL" -o /tmp/openjdk.sha256.raw; \
    \
    # Extract ONLY the checksum (first field)
    CHECKSUM=$(cut -d ' ' -f1 /tmp/openjdk.sha256.raw); \
    echo "${CHECKSUM}  /tmp/openjdk.tar.gz" > /tmp/openjdk.sha256.txt; \
    \
    sha256sum -c /tmp/openjdk.sha256.txt; \
    \
    mkdir -p "$JAVA_HOME"; \
    tar -xzf /tmp/openjdk.tar.gz -C "$JAVA_HOME" --strip-components=1; \
    \
    rm -f /tmp/openjdk.tar.gz /tmp/openjdk.sha256.txt /tmp/openjdk.sha256.raw /tmp/release.json


#
# === Non‑Root User ===
#
ENV USER_ID=1010
ENV USER_NAME=appuser

RUN useradd -m -u "$USER_ID" -s /bin/bash "$USER_NAME"

#
# === Maven Install ===
#
RUN set -eux; \
    wget --no-verbose -O maven.tar.gz \
      "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
    echo "${MAVEN_DOWNLOAD_SHA512}  maven.tar.gz" | sha512sum -c -; \
    mkdir -p "${MAVEN_HOME}"; \
    tar -xzf maven.tar.gz -C "${MAVEN_HOME}" --strip-components=1; \
    rm maven.tar.gz

RUN mkdir -p /home/appuser/.m2 && \
    chown -R appuser:appuser /home/appuser && \
    chmod 700 /home/appuser && \
    chmod 700 /home/appuser/.m2 && \
    apt-get purge -y wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*


VOLUME /home/appuser/.m2

COPY --chmod=755 entrypoint.sh /__cacert_entrypoint.sh

USER 1010
ENTRYPOINT ["/__cacert_entrypoint.sh"]
