#!/usr/bin/env bash
set -euo pipefail


# Ensure system python for gcloud
export CLOUDSDK_PYTHON=${CLOUDSDK_PYTHON:-python3}

# Prefer user config dir, fall back to root config
if [ -d "/liquibase/.config/gcloud" ]; then
  export CLOUDSDK_CONFIG="/liquibase/.config/gcloud"
else
  export CLOUDSDK_CONFIG="/root/.config/gcloud"
fi

# Ensure config dir exists and is writable by current user (best-effort)
mkdir -p "${CLOUDSDK_CONFIG}"
chmod 700 "${CLOUDSDK_CONFIG}" || true
# chown may fail if not root; ignore errors
chown -R "$(id -u):$(id -g)" "${CLOUDSDK_CONFIG}" 2>/dev/null || true

# If ADC JSON is mounted at /liquibase/adc.json, set GOOGLE_APPLICATION_CREDENTIALS
if [ -f "/liquibase/adc.json" ]; then
  export GOOGLE_APPLICATION_CREDENTIALS="/liquibase/adc.json"
fi

# Activate service account if key is provided (local/test). For Workload Identity on GKE no key is needed.
if [ -f "/liquibase/sa-key.json" ]; then
  echo "Activating service account from /liquibase/sa-key.json"
  if command -v /liquibase/google-cloud-sdk/bin/gcloud >/dev/null 2>&1; then
    /liquibase/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=/liquibase/sa-key.json --quiet || {
      echo "ERROR: Failed to activate service account" >&2
      exit 1
    }
  else
    echo "WARNING: gcloud not found; skipping service account activation" >&2
  fi
fi

# Optional: print short versions for debugging (non-fatal)
if command -v /liquibase/google-cloud-sdk/bin/gcloud >/dev/null 2>&1; then
  /liquibase/google-cloud-sdk/bin/gcloud --version || true
fi
java -version 2>&1 | head -n 1 || true
[ -x /liquibase/liquibase ] && /liquibase/liquibase --version 2>/dev/null || true
[ -x /liquibase/bin/lpm ] && /liquibase/bin/lpm --version 2>/dev/null || true
# If INSTALL_MYSQL is set, install mysql plugin globally via lpm
if [[ -n "${INSTALL_MYSQL:-}" ]]; then
  if command -v /liquibase/bin/lpm >/dev/null 2>&1 || command -v lpm >/dev/null 2>&1; then
    echo "INSTALL_MYSQL is set: installing mysql via lpm"
    if [ -x /liquibase/bin/lpm ]; then
      /liquibase/bin/lpm add mysql --global || true
    else
      lpm add mysql --global || true
    fi
  else
    echo "WARNING: lpm not found; cannot install mysql plugin" >&2
  fi
fi

# [ -n "${url:-}" ] && echo "url: $url" >> /liquibase/liquibase.docker.properties
# [ -n "${database:-}" ] && echo "database: $database" >> /liquibase/liquibase.docker.properties
# [ -n "${project:-}" ] && echo "project: $project" >> /liquibase/liquibase.docker.properties
# [ -n "${environment:-}" ] && echo "environment: $environment" >> /liquibase/liquibase.docker.properties


# --- Original liquibase entrypoint behavior preserved ---
# If first arg is an OS command (and not liquibase 'history' or 'init'), exec it.
if [ $# -gt 0 ]; then
  first="$1"
  if [[ "$first" != "history" && "$first" != "init" ]] && command -v "$first" >/dev/null 2>&1; then
    exec "$@"
  else
    if [[ "$*" == *--defaultsFile* ]] || [[ "$*" == *--defaults-file* ]] || [[ "$*" == *--version* ]]; then
      exec /liquibase/liquibase "$@"
    else
      exec /liquibase/liquibase "--defaultsFile=/liquibase/liquibase.docker.properties" "$@"
    fi
  fi
else
  # No args provided: start an interactive shell
  exec bash
fi
