#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

VERSION="$VERSION"
CHARTS_RELEASE_ASSET_URL=https://github.com/syntho-ai/syntho-charts/archive/refs/tags/${VERSION}.tar.gz
TARBALL_DESTINATION=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}.tar.gz
EXTRACT_LOCATION=${DEPLOYMENT_DIR}

download_release() {
    local errors=""

    if ! command_exists "curl"; then
        if ! curl -LJ "${CHARTS_RELEASE_ASSET_URL}" -o "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
            errors+="Error: Failed to download release using curl. Make sure that the given version exists.\n"
        fi
    else
        if ! wget "${CHARTS_RELEASE_ASSET_URL}" -O "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
            errors+="Error: Failed to download release using wget. Make sure that the given version exists.\n"
        fi
    fi

    echo -n "$errors"
}

extract_release() {
    sleep 1
    local errors=""


    if ! tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}" >/dev/null 2>&1; then
        errors+="Error: Failed to extract the release\n"
    fi

    echo -n "$errors"
}


with_loading "Downloading the release: $VERSION" download_release
with_loading "Extracting the release: $VERSION" extract_release
