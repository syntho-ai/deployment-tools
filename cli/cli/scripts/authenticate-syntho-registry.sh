#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"
SYNTHO_REGISTRY="$SYNTHO_REGISTRY"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"

authenticate_registry() {
    sleep 2
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/authenticate_registry.log"

    if ! auth_syntho >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Authentication failed.\n"
    fi

    write_and_exit "$errors" "authenticate_registry"
}

auth_syntho() {
    PWD_LENGTH=${#REGISTRY_PWD}

    # Extract the middle part only if REGISTRY_PWD is long enough
    MIDDLE_PART=${REGISTRY_PWD:5:$PWD_LENGTH-10}

    # If REGISTRY_PWD is shorter than 10 characters, mask the whole string
    if (( PWD_LENGTH < 10 )); then
        MIDDLE_PART=""
    fi

    MASKED_PWD=$(printf '*%.0s' {1..5})$MIDDLE_PART$(printf '*%.0s' {1..5})

    echo "login command: echo \"$MASKED_PWD\" | docker login -u $REGISTRY_USER --password-stdin $SYNTHO_REGISTRY"
    echo "$REGISTRY_PWD" | docker login -u $REGISTRY_USER --password-stdin $SYNTHO_REGISTRY
}

with_loading "Authentication with the Syntho image registry" authenticate_registry
