#!/usr/bin/env bash
# Verify (and optionally rebuild) the photos-apache Docker image.
#
# Usage:
#   bin/docker-check.sh          # check only; exit 1 if stale or missing
#   bin/docker-check.sh --build  # rebuild if stale or missing, no-op if current
#   bin/docker-check.sh --force  # always rebuild

set -eo pipefail

SDIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

case "${1:-}" in
    "")       MODE=check ;;
    --build)  MODE=build ;;
    --force)  MODE=force ;;
    *) echo "Usage: $0 [--build|--force]" >&2; exit 1 ;;
esac

expected=$(cat "$SDIR/../web/Dockerfile" "$SDIR/../web/entrypoint.sh" | shasum -a 256 | cut -d' ' -f1)

_build() {
    docker build -t photos-apache --label "ddphotos.hash=$expected" "$SDIR/../web/"
}

if [ "$MODE" = force ]; then
    _build
    exit 0
fi

stored=$(docker image inspect photos-apache --format '{{index .Config.Labels "ddphotos.hash"}}' 2>/dev/null || true)

if [ "$stored" = "$expected" ]; then
    exit 0
fi

if [ "$MODE" = build ]; then
    echo "=== Building Docker image (stale or missing) ==="
    _build
else
    echo "ERROR: photos-apache image is stale or missing."
    echo "Run: make web-docker-build"
    exit 1
fi
