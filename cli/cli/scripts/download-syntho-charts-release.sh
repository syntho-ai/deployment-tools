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
            errors+="Failed to download release using curl. Make sure that the given version exists.\n"
        fi
    else
        if ! wget "${CHARTS_RELEASE_ASSET_URL}" -O "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
            errors+="Failed to download release using wget. Make sure that the given version exists.\n"
        fi
    fi

    write_and_exit "$errors" "download_release"
}

extract_release() {
    sleep 1
    local errors=""


    if ! tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}" >/dev/null 2>&1; then
        errors+="Failed to extract the release\n"
    fi

    write_and_exit "$errors" "extract_release"
}




with_loading "Downloading the release: $VERSION" download_release
with_loading "Extracting the release: $VERSION" extract_release


RELEASE_CONFIG_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/helm/config
cp ${RELEASE_CONFIG_DIR}/images.env ${DEPLOYMENT_DIR}/.images.env
cp ${RELEASE_CONFIG_DIR}/images-arm.env ${DEPLOYMENT_DIR}/.images-arm.env

source ${DEPLOYMENT_DIR}/.images.env --source-only
IMAGE_REGISTRY_SERVER="${IMAGE_REGISTRY_SERVER-syntho.azurecr.io}"
echo "IMAGE_REGISTRY_SERVER=$IMAGE_REGISTRY_SERVER" >> "$DEPLOYMENT_DIR/.pre.deployment.ops.env"

CHARTS_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/helm
echo "CHARTS_DIR=$CHARTS_DIR" >> "$DEPLOYMENT_DIR/.pre.deployment.ops.env"
