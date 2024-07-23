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
CURRENT_RELEASE_DEPLOYMENT_TOOLING_DIR=${CURRENT_RELEASE_ASSET_DESTINATION_DIR}/${DEPLOYMENT_TOOLING}
CURRENT_RELEASE_DEPLOYMENT_QUESTIONS_PATH=${CURRENT_RELEASE_ASSET_DESTINATION_DIR}/dynamic-configuration/src/${CONFIGURATION_QUESTIONS_PREFIX}_questions.yaml


NEW_RELEASE_ASSET_URL=https://github.com/syntho-ai/deployment-tools/releases/download/${NEW_VERSION}/syntho-${NEW_VERSION}.tar.gz
NEW_RELEASE_ASSET_DESTINATION="${TEMP_DIR}/syntho-${NEW_VERSION}.tar.gz"
NEW_RELEASE_ASSET_DESTINATION_DIR="${TEMP_DIR}/syntho-${NEW_VERSION}"
mkdir -p "${NEW_RELEASE_ASSET_DESTINATION_DIR}"
NEW_RELEASE_DEPLOYMENT_TOOLING_DIR=${NEW_RELEASE_ASSET_DESTINATION_DIR}/${DEPLOYMENT_TOOLING}
NEW_RELEASE_DEPLOYMENT_QUESTIONS_PATH=${NEW_RELEASE_ASSET_DESTINATION_DIR}/dynamic-configuration/src/${CONFIGURATION_QUESTIONS_PREFIX}_questions.yaml


fetch_releases() {
    local errors=""

    if ! command_exists "curl"; then
        if ! curl -L -o "${CURRENT_RELEASE_ASSET_DESTINATION}" "${CURRENT_RELEASE_ASSET_URL}" >/dev/null 2>&1; then
            errors+="Failed to download current release using curl. Make sure that the given version exists.\n"
        fi
        if ! curl -L -o "${NEW_RELEASE_ASSET_DESTINATION}" "${NEW_RELEASE_ASSET_URL}" >/dev/null 2>&1; then
            errors+="Failed to download new release using curl. Make sure that the given version exists.\n"
        fi
    else
        if ! wget -O "${CURRENT_RELEASE_ASSET_DESTINATION}" "${CURRENT_RELEASE_ASSET_URL}" >/dev/null 2>&1; then
            errors+="Failed to download current release using wget. Make sure that the given version exists.\n"
        fi
        if ! wget -O "${NEW_RELEASE_ASSET_DESTINATION}" "${NEW_RELEASE_ASSET_URL}" >/dev/null 2>&1; then
            errors+="Failed to download new release using wget. Make sure that the given version exists.\n"
        fi
    fi

    if ! extract_releases >/dev/null 2>&1; then
        errors+="Failed to extract current and new releases\n"
    fi

    write_and_exit "$errors" "fetch_releases"
}

extract_releases() {
    tar -xzvf "${CURRENT_RELEASE_ASSET_DESTINATION}" -C "${CURRENT_RELEASE_ASSET_DESTINATION_DIR}"
    tar -xzvf "${NEW_RELEASE_ASSET_DESTINATION}" -C "${NEW_RELEASE_ASSET_DESTINATION_DIR}"
}

check_if_compatible() {
    local errors=""

    if ! diff -q "$CURRENT_RELEASE_DEPLOYMENT_QUESTIONS_PATH" "$NEW_RELEASE_DEPLOYMENT_QUESTIONS_PATH" >/dev/null 2>&1; then
        errors+="There are discrepancies between configuration questions, therefore the new release is incompatible\n"
    fi

    if ! diff -rq "$CURRENT_RELEASE_DEPLOYMENT_TOOLING_DIR" "$NEW_RELEASE_DEPLOYMENT_TOOLING_DIR" >/dev/null 2>&1; then
        errors+="There are discrepancies between releases, therefore the new release is incompatible\n"
    fi

    write_and_exit "$errors" "check_if_compatible"
}

cleanup_files_and_directories() {
    local errors=""

    if ! rm -rf "$TEMP_DIR" >/dev/null 2>&1; then
        errors+="Unexpected failure when cleaning up stale files and directories\n"
    fi

    write_and_exit "$errors" "cleanup_files_and_directories"
}


with_loading "Fetching the releases: $CURRENT_VERSION vs $NEW_VERSION" fetch_releases
with_loading "Checking if the releases are compatible: $CURRENT_VERSION vs $NEW_VERSION" check_if_compatible
with_loading "Cleanup tempoary files and directories" cleanup_files_and_directories
