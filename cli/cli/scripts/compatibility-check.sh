#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
TEMP_DIR="$DEPLOYMENT_DIR/temp-compatibility-check"
mkdir -p "$TEMP_DIR"

DEPLOYMENT_TOOLING="$DEPLOYMENT_TOOLING"
CONFIGURATION_QUESTIONS_PREFIX="$CONFIGURATION_QUESTIONS_PREFIX"
CURRENT_VERSION="$CURRENT_VERSION"
NEW_VERSION="$NEW_VERSION"


CURRENT_RELEASE_ASSET_URL=https://github.com/syntho-ai/deployment-tools/releases/download/${CURRENT_VERSION}/syntho-${CURRENT_VERSION}.tar.gz
CURRENT_RELEASE_ASSET_DESTINATION="${TEMP_DIR}/syntho-${CURRENT_VERSION}.tar.gz"
CURRENT_RELEASE_ASSET_DESTINATION_DIR="${TEMP_DIR}/syntho-${CURRENT_VERSION}"
mkdir -p "${CURRENT_RELEASE_ASSET_DESTINATION_DIR}"
# shellcheck disable=SC2034
CURRENT_RELEASE_DEPLOYMENT_TOOLING_DIR=${CURRENT_RELEASE_ASSET_DESTINATION_DIR}/${DEPLOYMENT_TOOLING}
# shellcheck disable=SC2034
CURRENT_RELEASE_DEPLOYMENT_QUESTIONS_PATH=${CURRENT_RELEASE_ASSET_DESTINATION_DIR}/dynamic-configuration/src/${CONFIGURATION_QUESTIONS_PREFIX}_questions.yaml


NEW_RELEASE_ASSET_URL=https://github.com/syntho-ai/deployment-tools/releases/download/${NEW_VERSION}/syntho-${NEW_VERSION}.tar.gz
NEW_RELEASE_ASSET_DESTINATION="${TEMP_DIR}/syntho-${NEW_VERSION}.tar.gz"
NEW_RELEASE_ASSET_DESTINATION_DIR="${TEMP_DIR}/syntho-${NEW_VERSION}"
# shellcheck disable=SC2034
mkdir -p "${NEW_RELEASE_ASSET_DESTINATION_DIR}"
# shellcheck disable=SC2034
NEW_RELEASE_DEPLOYMENT_TOOLING_DIR=${NEW_RELEASE_ASSET_DESTINATION_DIR}/${DEPLOYMENT_TOOLING}
# shellcheck disable=SC2034
NEW_RELEASE_DEPLOYMENT_QUESTIONS_PATH=${NEW_RELEASE_ASSET_DESTINATION_DIR}/dynamic-configuration/src/${CONFIGURATION_QUESTIONS_PREFIX}_questions.yaml


fetch_releases() {
    local errors=""

    # Function to check if a file exists and download if it doesn't
    download_if_not_exists() {
        local destination=$1
        local url=$2
        local tool=$3
        local error_message=$4

        if [ ! -f "$destination" ]; then
            if [ "$tool" == "curl" ]; then
                if ! curl -L -o "$destination" "$url" >/dev/null 2>&1; then
                    errors+="$error_message\n"
                fi
            else
                if ! wget -O "$destination" "$url" >/dev/null 2>&1; then
                    errors+="$error_message\n"
                fi
            fi
        fi
    }

    if command_exists "curl"; then
        download_if_not_exists "${CURRENT_RELEASE_ASSET_DESTINATION}" "${CURRENT_RELEASE_ASSET_URL}" "curl" "Failed to download current release using curl. Make sure that the given version exists."
        download_if_not_exists "${NEW_RELEASE_ASSET_DESTINATION}" "${NEW_RELEASE_ASSET_URL}" "curl" "Failed to download new release using curl. Make sure that the given version exists."
    else
        download_if_not_exists "${CURRENT_RELEASE_ASSET_DESTINATION}" "${CURRENT_RELEASE_ASSET_URL}" "wget" "Failed to download current release using wget. Make sure that the given version exists."
        download_if_not_exists "${NEW_RELEASE_ASSET_DESTINATION}" "${NEW_RELEASE_ASSET_URL}" "wget" "Failed to download new release using wget. Make sure that the given version exists."
    fi

    if ! extract_releases >/dev/null 2>&1; then
        errors+="Failed to extract current and new releases\n"
    fi

    write_and_exit "$errors" "fetch_releases"
}

extract_releases() {
    # Function to check if a directory is empty or non-existent and extract tar file if it is
    extract_if_empty_or_not_exists() {
        local tar_file=$1
        local dest_dir=$2

        if [ ! -d "$dest_dir" ] || [ -z "$(ls -A "$dest_dir")" ]; then
            mkdir -p "$dest_dir"
            tar -xzvf "$tar_file" -C "$dest_dir"
        fi
    }

    extract_if_empty_or_not_exists "${CURRENT_RELEASE_ASSET_DESTINATION}" "${CURRENT_RELEASE_ASSET_DESTINATION_DIR}"
    extract_if_empty_or_not_exists "${NEW_RELEASE_ASSET_DESTINATION}" "${NEW_RELEASE_ASSET_DESTINATION_DIR}"
}

check_if_compatible() {
    local errors=""

    ## ATTENTION ##
    # For now we decided to lift this compatible check, we will decide whether a release is
    # compatible or not. However, we are keeping this if we want/need to add a further
    # compatibility analysis check even though a release's semantic version looks it is compatible.
    # This is now justa  placeholder and does nothing.
    ## ATTENTION ##

    ## EXAMPLE CHECKS ##
    # 1. check whether there is a question diff
    # if ! diff -q "$CURRENT_RELEASE_DEPLOYMENT_QUESTIONS_PATH" "$NEW_RELEASE_DEPLOYMENT_QUESTIONS_PATH" >/dev/null 2>&1; then
    #     errors+="There are discrepancies between configuration questions, therefore the new release is incompatible\n"
    # fi

    # 2. check whether there is a file diff
    # if ! diff -rq "$CURRENT_RELEASE_DEPLOYMENT_TOOLING_DIR" "$NEW_RELEASE_DEPLOYMENT_TOOLING_DIR" >/dev/null 2>&1; then
    #     errors+="There are discrepancies between releases, therefore the new release is incompatible\n"
    # fi
    ## EXAMPLE CHECKS ##

    # a random step to fake the step
    sleep 2

    write_and_exit "$errors" "check_if_compatible"
}


with_loading "Fetching the releases: $CURRENT_VERSION vs $NEW_VERSION" fetch_releases
with_loading "Checking if the releases are compatible: $CURRENT_VERSION vs $NEW_VERSION" check_if_compatible
