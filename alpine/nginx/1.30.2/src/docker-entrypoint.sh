#!/bin/sh
set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# Only run scripts if nginx is the main command
if [ "$1" = "nginx" ] || [ "$1" = "nginx-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        entrypoint_log "$0: /docker-entrypoint.d/ is not empty, running configuration scripts"

        for f in $(find /docker-entrypoint.d/ -type f -print | sort -V); do
            case "$f" in
                *.envsh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Sourcing $f"
                        . "$f"
                    fi
                    ;;
                *.sh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Executing $f"
                        "$f"
                    fi
                    ;;
                *)
                    entrypoint_log "$0: Ignoring $f"
                    ;;
            esac
        done

        entrypoint_log "$0: Configuration complete"
    fi
fi

exec "$@"
