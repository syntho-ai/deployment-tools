#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

SHARED="$DEPLOYMENT_DIR/shared"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"

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

    local DC_IMAGES_ENV_TEMPLATE_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/docker-compose/config/images.env.tpl"
    local DC_IMAGES_ENV_OUTPUT_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/docker-compose/config/images.env"

    sed "s|{{ SYNTHO_STACK_VERSION }}|$VERSION|g" "$DC_IMAGES_ENV_TEMPLATE_FILE" > "$DC_IMAGES_ENV_OUTPUT_FILE"

    DC_IMAGES_ENV_TEMPLATE_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/docker-compose/config/images-arm.env.tpl"
    DC_IMAGES_ENV_OUTPUT_FILE="$EXTRACT_LOCATION/syntho-charts-${VERSION}/docker-compose/config/images-arm.env"

    sed "s|{{ SYNTHO_STACK_VERSION }}|$VERSION|g" "$DC_IMAGES_ENV_TEMPLATE_FILE" > "$DC_IMAGES_ENV_OUTPUT_FILE"
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

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/extract_release.log"


    if ! tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}" >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Failed to extract the release\n"
    fi

    if ! replace_version_in_images_env >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Failed to replace version in images.env\n"
    fi

    write_and_exit "$errors" "extract_release"
}




with_loading "Downloading the release: $VERSION" download_release
with_loading "Extracting the release: $VERSION" extract_release


RELEASE_CONFIG_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/docker-compose/config
cp ${RELEASE_CONFIG_DIR}/images.env ${DEPLOYMENT_DIR}/.images.env
cp ${RELEASE_CONFIG_DIR}/images-arm.env ${DEPLOYMENT_DIR}/.images-arm.env

DC_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/docker-compose
echo "DC_DIR=$DC_DIR" >> "$DEPLOYMENT_DIR/.pre.deployment.ops.env"
