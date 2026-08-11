FROM eclipse-temurin:21-jdk-alpine AS builder
LABEL maintainer="hareesh <hareesh.uk4839@gmail.com>"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MAVEN_HOME=/opt/maven \
    MAVEN_VERSION=3.9.16

# --- CIS HARDENING: Minimal packages, no shells beyond bash, no compilers ---
RUN set -eux; \
    apk update && apk upgrade && \
    apk add --no-cache \
        ca-certificates \
        tzdata \
        bash \
        coreutils \
        wget \
        unzip \
        git \
        git-lfs \
        mercurial \
        subversion && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

# --- CIS HARDENING: Non-root user ---
RUN set -o errexit -o nounset \
    && echo "Adding appuser user and group" \
    && addgroup --system --gid 1010 appuser \
    && adduser --system --ingroup appuser --uid 1010 --shell /bin/ash appuser \
    && mkdir /home/appuser/.appuser \
    && chown -R appuser:appuser /home/appuser \
    && chmod 700 /home/appuser && mkdir -p /home/appuser/.m2 && chmod 700 /home/appuser/.m2
WORKDIR /home/appuser

# --- Maven Download + SHA Verification ---
ARG MAVEN_DOWNLOAD_SHA512="831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6"
RUN set -eux; \
    wget --no-verbose -O maven.tar.gz \
      "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
    echo "${MAVEN_DOWNLOAD_SHA512}  maven.tar.gz" | sha512sum -c -; \
    mkdir -p "${MAVEN_HOME}"; \
    tar -xzf maven.tar.gz -C "${MAVEN_HOME}" --strip-components=1; \
    rm maven.tar.gz

ENV PATH="${MAVEN_HOME}/bin:${PATH}"


VOLUME /home/appuser/.m2

########## STAGE 2: RUNTIME (JRE 21 + Hardened) ##########
FROM eclipse-temurin:21-jre-alpine AS runtime
USER root
# --- CIS HARDENING: Minimal runtime footprint ---
RUN set -eux; \
    apk update && apk upgrade && \
    apk add --no-cache \
        ca-certificates tzdata bash coreutils net-tools traceroute curl yq openssl && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

# --- CIS HARDENING: Non-root runtime user ---
RUN set -o errexit -o nounset \
    && echo "Adding appuser user and group" \
    && addgroup --system --gid 1010 appuser \
    && adduser --system --ingroup appuser --uid 1010 --shell /bin/ash appuser \
    && mkdir /home/appuser/.appuser \
    && chown -R appuser:appuser /home/appuser \
    && chmod 700 /home/appuser && mkdir -p /home/appuser/.m2 && chmod 700 /home/appuser/.m2
WORKDIR /home/appuser

# --- Copy Maven from builder stage ---
ENV MAVEN_HOME=/opt/maven
ENV MAVEN_VERSION=3.9.16
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

COPY --from=builder --chmod=0755 --chown=appuser:appuser /opt/maven /opt/maven
RUN mkdir -p /home/appuser/.m2 && chmod 700 /home/appuser/.m2

COPY --chmod=0755 --chown=appuser:appuser entrypoint.sh /entrypoint.sh
VOLUME /home/appuser/.m2
# --- CIS HARDENING: No shell entrypoint, no root, no extra capabilities ---
ENTRYPOINT ["/entrypoint.sh"]
USER 1010
CMD ["mvn"]