#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
SYNTHO_REGISTRY="$SYNTHO_REGISTRY"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"

deauthenticate_registry() {
    sleep 2
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/deauthenticate_registry.log"

    if ! deauth_syntho >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Removing authentication credentials failed.\n"
    fi

    write_and_exit "$errors" "deauthenticate_registry"
}

deauth_syntho() {
    echo "logout command: docker logout $SYNTHO_REGISTRY"
    docker logout $SYNTHO_REGISTRY
}

with_loading "Removing authentication credentials for Syntho image registry" deauthenticate_registry
