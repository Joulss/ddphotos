#!/usr/bin/env bash
# Deploy ddphotos-test site to https://ddphotos-test.donohoe.info
#
# Usage:
#   bin/deploy-ddphotos-test.sh [--dev] [--no-photogen] [--no-build] [--doit] [--verify]
#
# Options:
#   --dev         Use local 'ddphotos' image (default: dougdonohoe/ddphotos:latest)
#   --no-photogen Skip the photogen step
#   --no-build    Skip the build step
#   --doit        Actually run deploy (default: dry-run, skips deploy)
#   --verify      Instead of deploying, verify the site via test-photos-server.sh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOMAIN="ddphotos-test.donohoe.info"
IMAGE="dougdonohoe/ddphotos:latest"
PULL_FLAG=(--pull always)
DOIT=false
VERIFY=false
DO_PHOTOGEN=true
DO_BUILD=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev)         IMAGE="ddphotos"; PULL_FLAG=(); shift ;;
        --no-photogen) DO_PHOTOGEN=false;              shift ;;
        --no-build)    DO_BUILD=false;                 shift ;;
        --doit)        DOIT=true;                      shift ;;
        --verify)      VERIFY=true;                    shift ;;
        --help|-h)
            echo "Usage: bin/deploy-ddphotos-test.sh [--dev] [--no-photogen] [--no-build] [--doit] [--verify]"
            echo ""
            echo "  --dev         Use local 'ddphotos' image (default: dougdonohoe/ddphotos:latest)"
            echo "  --no-photogen Skip the photogen step"
            echo "  --no-build    Skip the build step"
            echo "  --doit        Actually run deploy (default: dry-run, skips deploy)"
            echo "  --verify      Instead of deploying, verify the site via test-photos-server.sh"
            exit 0
            ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
done

DEPLOY_DIR="$HOME/junk/ddphotos-test"
mkdir -p "$DEPLOY_DIR"

step() { echo; echo "=== $* ==="; }

if $VERIFY; then
    step "verify: https://$DOMAIN"
    "$SCRIPT_DIR/test-photos-server.sh" --remote "https://$DOMAIN" --s3
    echo
    echo "Done."
    exit 0
fi

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
sed -i '' "s/photos\.yourdomain\.com/$DOMAIN/g" "$DEPLOY_DIR/config/albums.yaml"

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
    echo "Deployed https://$DOMAIN"
else
    echo
    echo "deploy: skipping (--doit not set)"
fi

echo
echo "Done."
