#!/usr/bin/env bash
# Deploy ddphotos-test site to https://ddphotos-test.donohoe.info
#
# Usage:
#   bin/deploy-ddphotos-test.sh [--dev] [--no-photogen] [--no-build] [--doit]
#
# Options:
#   --dev         Use local 'ddphotos' image (default: dougdonohoe/ddphotos:latest)
#   --no-photogen Skip the photogen step
#   --no-build    Skip the build step
#   --doit        Actually run deploy (default: dry-run, skips deploy)

set -eo pipefail

IMAGE="dougdonohoe/ddphotos:latest"
PULL_FLAG=(--pull always)
DOIT=false
DO_PHOTOGEN=true
DO_BUILD=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev)         IMAGE="ddphotos"; PULL_FLAG=(); shift ;;
        --no-photogen) DO_PHOTOGEN=false;              shift ;;
        --no-build)    DO_BUILD=false;                 shift ;;
        --doit)        DOIT=true;                      shift ;;
        --help|-h)
            echo "Usage: bin/deploy-ddphotos-test.sh [--dev] [--no-photogen] [--no-build] [--doit]"
            echo ""
            echo "  --dev         Use local 'ddphotos' image (default: dougdonohoe/ddphotos:latest)"
            echo "  --no-photogen Skip the photogen step"
            echo "  --no-build    Skip the build step"
            echo "  --doit        Actually run deploy (default: dry-run, skips deploy)"
            exit 0
            ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
done

DEPLOY_DIR="$HOME/junk/ddphotos-test"
mkdir -p "$DEPLOY_DIR"

step() { echo; echo "=== $* ==="; }

# Init (or update script only if already initialized)
if [ -z "$(ls -A "$DEPLOY_DIR")" ]; then
    step "docker: init"
    docker run "${PULL_FLAG[@]}" --rm -v "$DEPLOY_DIR":/ddphotos "$IMAGE" init
else
    step "docker: init --script-only"
    docker run "${PULL_FLAG[@]}" --rm -v "$DEPLOY_DIR":/ddphotos "$IMAGE" init --script-only
fi

# Update config
step "config"
/bin/cp ~/work/infra/photos/ddphotos-test/site.env "$DEPLOY_DIR/config/"
sed -i '' 's/photos\.yourdomain\.com/ddphotos-test.donohoe.info/g' "$DEPLOY_DIR/config/albums.yaml"

if $DO_PHOTOGEN; then
    step "photogen"
    "$DEPLOY_DIR/ddphotos" --show-mounts photogen
else
    echo "photogen: skipping (--no-photogen set)"
fi

if $DO_BUILD; then
    step "build"
    "$DEPLOY_DIR/ddphotos" --show-mounts build
else
    echo "build: skipping (--no-build set)"
fi

if $DOIT; then
    step "deploy"
    "$DEPLOY_DIR/ddphotos" --show-mounts deploy
    echo "Deployed https://ddphotos-test.donohoe.info"
else
    echo
    echo "deploy: skipping (--doit not set)"
fi

echo
echo "Done."
