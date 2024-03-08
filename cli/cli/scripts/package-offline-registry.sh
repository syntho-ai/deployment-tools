#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

ARCHIVE_FILE_NAME="$ARCHIVE_FILE_NAME"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"


package_registry() {
    sleep 1
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/package_registry.log"

    if ! archive_registry >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when archiving the offline registry files\n"
    fi

    write_and_exit "$errors" "package_registry"
}

archive_registry() {
    echo "archiving all the offline registry files"
    tar --exclude='./shared/process/*.log' -czvf "$ARCHIVE_FILE_NAME" -C "$DEPLOYMENT_DIR" .
    local exit_status=$?
    echo "Tar exit status: $exit_status"
    return $exit_status
}


with_loading "Packaging the offline registry" package_registry
