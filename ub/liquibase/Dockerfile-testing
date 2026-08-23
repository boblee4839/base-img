FROM debian:trixie-slim as gcloud-builder

ENV CLOUD_SDK_VERSION=572.0.0
ENV PATH="/google-cloud-sdk/bin:${PATH}"

# Create user
RUN groupadd -g 1000 cloudsdk && \
    useradd -u 1000 -g cloudsdk -m cloudsdk

# Install dependencies
RUN set -eux; \
    apt-get update -yqq; \
    apt-get upgrade -yqq; \
    mkdir -p /tmp/apt-archives; \
    apt-get -o Dir::Cache::archives=/tmp/apt-archives install -y --no-install-recommends \
        curl \
        ca-certificates \
        tzdata \
        python3 \
        python3-crcmod \
        python3-openssl \
        bash \
        openssh-client \
        git \
        gnupg \
        unzip \
        coreutils; \
    rm -rf /tmp/apt-archives /var/lib/apt/lists/*

# Detect architecture (Debian names: amd64, arm64)
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        echo -n "x86_64" > /tmp/arch; \
    else \
        echo -n "arm" > /tmp/arch; \
    fi

# Install Google Cloud SDK
RUN set -eux; \
    ARCH="$(cat /tmp/arch)"; \
    curl -sO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz; \
    tar xzf google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz; \
    rm google-cloud-cli-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz; \
    gcloud config set core/disable_usage_reporting true; \
    gcloud config set component_manager/disable_update_check true; \
    gcloud config set metrics/environment github_docker_image; \
    gcloud components install gsutil bq alpha beta; \
    gcloud --version; \
    gcloud components list --filter="state!=Not Installed"

# Git credential helper
RUN git config --system credential.'https://source.developers.google.com'.helper gcloud.sh && \
    update-ca-certificates

# Remove build tools
RUN apt-get purge -y curl git unzip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove test keys from Google SDK
RUN rm -f \
    /google-cloud-sdk/.install/.backup/platform/gsutil/third_party/google-auth-library-python/tests/data/*.pem \
    /google-cloud-sdk/.install/.backup/platform/gsutil/third_party/urllib3/dummyserver/certs/*.key \
    /google-cloud-sdk/platform/gsutil/third_party/google-auth-library-python/tests/data/*.pem \
    /google-cloud-sdk/platform/gsutil/third_party/urllib3/dummyserver/certs/*.key \
    /google-cloud-sdk/platform/gsutil/third_party/requests/tests/certs/expired/ca/ca-private.key \
    /google-cloud-sdk/platform/gsutil/third_party/requests/tests/certs/expired/server/server.key \
    /google-cloud-sdk/platform/gsutil/third_party/requests/tests/certs/mtls/client/client.key \
    /google-cloud-sdk/platform/gsutil/third_party/requests/tests/certs/valid/server/server.key || true


FROM debian:trixie-slim as main
USER root

ENV liquibase_HOME="/liquibase" \
    CLOUDSDK_CONFIG="/liquibase/.config/gcloud" \
    CLOUD_SDK_CONFIG="/liquibase/.config/gcloud" \
    HOME="/liquibase" \
    REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

# Install dependencies
RUN set -eux; \
    apt-get update -yqq; \
    apt-get upgrade -yqq; \
    mkdir -p /tmp/apt-archives; \
    apt-get -o Dir::Cache::archives=/tmp/apt-archives install -y --no-install-recommends \
        wget curl ca-certificates unzip ca-certificates krb5-user libpam-krb5 gnupg openjdk-21-jre-headless python3 python3-openssl python3-crcmod; \
    rm -rf /tmp/apt-archives /var/lib/apt/lists/*

# Create liquibase user/group
RUN groupadd -g 1010 liquibase && \
    useradd -m -u 1010 -g liquibase liquibase && \
    mkdir -p /liquibase/bin /liquibase/lib /liquibase/.config/gcloud && \
    chown -R liquibase:liquibase /liquibase && chmod -R 0775 /liquibase; \
    chmod 0700 /liquibase/.config/gcloud; \
    update-ca-certificates

WORKDIR /liquibase
COPY --chown=liquibase:liquibase --chmod=0775 source/ /liquibase/
COPY --chown=liquibase:liquibase --chmod=0775 --from=gcloud-builder /google-cloud-sdk/  /liquibase/google-cloud-sdk/
ENV PATH=$PATH:/liquibase/google-cloud-sdk/bin/
# Install Liquibase
ARG liquibase_VERSION="5.0.3"
ARG LB_SHA256="865aab391be9cbe3fee22461392d5d29aa76652596598b14700a3f5f05c9e2b7"

RUN set -eux; \
    wget -q -O liquibase-${liquibase_VERSION}.tar.gz \
        "https://github.com/liquibase/liquibase/releases/download/v${liquibase_VERSION}/liquibase-${liquibase_VERSION}.tar.gz" && \
    echo "${LB_SHA256}  liquibase-${liquibase_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xzf liquibase-${liquibase_VERSION}.tar.gz && \
    rm liquibase-${liquibase_VERSION}.tar.gz && \
    ln -s /liquibase/liquibase /usr/local/bin/liquibase && \
    liquibase --version

# Install Liquibase Package Manager (LPM)
ARG LPM_VERSION="0.3.5"

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) DOWNLOAD_ARCH="" ;; \
        arm64) DOWNLOAD_ARCH="-arm64" ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    BASE_URL="https://github.com/liquibase/liquibase-package-manager/releases/download/v${LPM_VERSION}"; \
    curl -sLO "${BASE_URL}/checksums.txt"; \
    FILE="lpm-${LPM_VERSION}-linux${DOWNLOAD_ARCH}.zip"; \
    LPM_SHA256="$(grep "  ${FILE}" checksums.txt | awk '{print $1}')"; \
    wget -q -O "${FILE}" "${BASE_URL}/${FILE}"; \
    echo "${LPM_SHA256}  ${FILE}" | sha256sum -c -; \
    unzip "${FILE}" -d bin/; \
    chmod -R +x bin; \
    rm -f "${FILE}" checksums.txt; \
    ln -s /liquibase/bin/lpm /usr/local/bin/lpm; \
    lpm --version

# Install BigQuery JDBC driver
ARG SimbaJDBC_BQ_VERSION="42_1.7.0.1001"
RUN set -eux; \
    wget -q -O SimbaJDBC.zip \
        "https://storage.googleapis.com/simba-bq-release/jdbc/SimbaJDBCDriverforGoogleBigQuery${SimbaJDBC_BQ_VERSION}.zip"; \
    unzip SimbaJDBC.zip -d lib/; \
    rm -f SimbaJDBC.zip

# Install liquibase-bigquery extension
ARG LBBQ_SHA256="4757ca3a4bdf45886757b4863cdcd8498daca66a18879fef7313a909b25cf752"
RUN set -eux; \
    wget -q -O liquibase-bigquery-${liquibase_VERSION}.jar \
        "https://github.com/liquibase/liquibase-bigquery/releases/download/v${liquibase_VERSION}/liquibase-bigquery-${liquibase_VERSION}.jar"; \
    echo "${LBBQ_SHA256}  liquibase-bigquery-${liquibase_VERSION}.jar" | sha256sum -c -; \
    mv liquibase-bigquery-${liquibase_VERSION}.jar lib/

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* 
    
FROM debian:trixie-slim

LABEL project="self" \
      maintainer="hareesh" \
      name="gcloud-lqb-bq" \
      description="gcloud-lqb-bq"

USER root

ENV liquibase_HOME="/liquibase" \
    CLOUDSDK_CONFIG="/liquibase/.config/gcloud" \
    CLOUD_SDK_CONFIG="/liquibase/.config/gcloud" \
    HOME="/liquibase" \
    REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"

# # Install dependencies
# RUN apt-get update -yqq && apt-get upgrade -yqq && \
#     DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
#         ca-certificates krb5-user libpam-krb5 gnupg openjdk-21-jre-headless  python3 python3-openssl python3-crcmod

RUN set -eux; \
    apt-get update -yqq; \
    apt-get upgrade -yqq; \
    mkdir -p /tmp/apt-archives; \
    apt-get -o Dir::Cache::archives=/tmp/apt-archives install -y --no-install-recommends \
        ca-certificates tzdata krb5-user libpam-krb5 gnupg openjdk-21-jre-headless bash python3 python3-openssl python3-crcmod coreutils ; \
    rm -rf /tmp/apt-archives /var/lib/apt/lists/*        
# Create liquibase user/group
RUN groupadd -g 1010 liquibase && \
    useradd -m -u 1010 -g liquibase liquibase && \
    mkdir -p /liquibase/bin /liquibase/lib /liquibase/.config/gcloud && \
    chown -R liquibase:liquibase /liquibase && chmod -R 0775 /liquibase; \
    chmod 0700 /liquibase/.config/gcloud; \
    update-ca-certificates

WORKDIR /liquibase
COPY --chown=liquibase:liquibase --chmod=0775 --from=main /liquibase  /liquibase
ENV PATH=$PATH:/liquibase/google-cloud-sdk/bin/
RUN ln -s /liquibase/bin/lpm /usr/local/bin/lpm; \
    ln -s /liquibase/liquibase /usr/local/bin/liquibase; \
    apt-get clean && rm -rf /var/lib/apt/lists/* 
USER 1010
VOLUME ["/liquibase/changelog", "/liquibase/classpath", "/liquibase/.config/gcloud", "/root/.config/gcloud"]
ENTRYPOINT ["/liquibase/docker-entrypoint.sh"]
CMD ["bash"]