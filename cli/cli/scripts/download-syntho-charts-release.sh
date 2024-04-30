#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

VERSION="$VERSION"
DEPLOYMENT_TOOLS_VERSION="$DEPLOYMENT_TOOLS_VERSION"
CHARTS_ARCHIVE_LOCATION=${SCRIPT_DIR}/syntho-charts.tar.gz
TARBALL_DESTINATION=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}.tar.gz
EXTRACT_LOCATION=${DEPLOYMENT_DIR}

replace_version_in_images_env() {
    # this is for backwards-compatibility
    extracted_dir="${EXTRACT_LOCATION}/syntho-charts"
    new_dir_name="${EXTRACT_LOCATION}/syntho-charts-${VERSION}"
    mv "$extracted_dir" "$new_dir_name"

    local HELM_IMAGES_ENV_TEMPLATE_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/helm/config/images.env.tpl"
    local HELM_IMAGES_ENV_OUTPUT_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/helm/config/images.env"

    sed "s|{{ SYNTHO_STACK_VERSION }}|$VERSION|g" "$HELM_IMAGES_ENV_TEMPLATE_FILE" > "$HELM_IMAGES_ENV_OUTPUT_FILE"

    HELM_IMAGES_ENV_TEMPLATE_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/helm/config/images-arm.env.tpl"
    HELM_IMAGES_ENV_OUTPUT_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/helm/config/images-arm.env"

    sed "s|{{ SYNTHO_STACK_VERSION }}|$VERSION|g" "$HELM_IMAGES_ENV_TEMPLATE_FILE" > "$HELM_IMAGES_ENV_OUTPUT_FILE"
}

download_release() {
    local errors=""

    if ! cp "${CHARTS_ARCHIVE_LOCATION}" "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
        errors+="Failed to download release..\n"
    fi

    write_and_exit "$errors" "download_release"
}

extract_release() {
    sleep 1
    local errors=""


    if ! tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}" >/dev/null 2>&1; then
        errors+="Failed to extract the release\n"
    fi

    if ! replace_version_in_images_env >/dev/null 2>&1; then
        errors+="Failed to replace version in images.env\n"
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
