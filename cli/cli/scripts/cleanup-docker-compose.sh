#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only


DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
FORCE="$FORCE"
source $DEPLOYMENT_DIR/.env --source-only
DOCKER_CONFIG="$DOCKER_CONFIG"
DOCKER_HOST="$DOCKER_HOST"
DOCKER_SSH_USER_PRIVATE_KEY="$DOCKER_SSH_USER_PRIVATE_KEY"

if [ -d "$DEPLOYMENT_DIR" ] && [ -f "$DEPLOYMENT_DIR/.pre.deployment.ops.env" ]; then
    source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
    DC_DIR="$DC_DIR"
else
    DC_DIR=
fi


destroy() {
    DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST  docker compose -f $DC_DIR/docker-compose.yaml down --remove-orphans --volumes --rmi all
}

destroy_with_error_handling() {
    local errors=""


    if ! destroy >/dev/null 2>&1; then
        errors+="Failed to clean up components\n"
    fi

    write_and_exit "$errors" "destroy_with_error_handling"
}


if [ -n "$DC_DIR" ]; then
    if [[ $DOCKER_HOST == ssh://* ]] && [[ -n $DOCKER_SSH_USER_PRIVATE_KEY ]]; then
        eval "$(ssh-agent -s)"
        SSH_AGENT_PID=$SSH_AGENT_PID
        ssh-add $DOCKER_SSH_USER_PRIVATE_KEY
        SSH_AUTH_SOCK=$SSH_AUTH_SOCK
    fi

    with_loading "Cleaning things up (destroying)" destroy_with_error_handling 300

    if [[ $DOCKER_HOST == ssh://* ]] && [[ -n $DOCKER_SSH_USER_PRIVATE_KEY ]]; then
        kill $SSH_AGENT_PID
        unset SSH_AUTH_SOCK
        unset SSH_AGENT_PID
    fi
fi
