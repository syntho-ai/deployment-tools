#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only


DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
FORCE="$FORCE"
source $DEPLOYMENT_DIR/.env --source-only
DOCKER_CONFIG="$DOCKER_CONFIG"

source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
DC_DIR="$DC_DIR"

destroy() {
    DOCKER_CONFIG=$DOCKER_CONFIG docker compose -f $DC_DIR/docker-compose.yaml down --remove-orphans --volumes --rmi all
}

destroy_with_error_handling() {
    local errors=""


    if ! destroy >/dev/null 2>&1; then
        errors+="Failed to clean up components\n"
    fi

    echo -n "$errors"
}

with_loading "Cleaning things up (destroying)" destroy_with_error_handling 300
