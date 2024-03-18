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

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"


destroy() {
    DOCKER_HOST=$DOCKER_HOST docker compose -f $DC_DIR/docker-compose.yaml down --remove-orphans --volumes --rmi all
}

destroy_offline_registry_if_exists() {
    CONTAINER_NAME="syntho-offline-registry"

    if [ "$(DOCKER_HOST=$DOCKER_HOST docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "Container $CONTAINER_NAME exists. Stopping and removing it..."
        DOCKER_HOST=$DOCKER_HOST docker stop $CONTAINER_NAME
        DOCKER_HOST=$DOCKER_HOST docker rm $CONTAINER_NAME
    else
        echo "Offline registry container $CONTAINER_NAME does not exist and moving on"
    fi
}

destroy_with_error_handling() {
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/destroy_with_error_handling.log"

    if ! destroy >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Failed to clean up components\n"
    fi

    if ! destroy_offline_registry_if_exists >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Failed to clean up components\n"
    fi

    write_and_exit "$errors" "destroy_with_error_handling"
}



if [[ -f "${DEPLOYMENT_DIR}/.ssh-sock.env" ]] && [[ -f "${DEPLOYMENT_DIR}/.ssh-agent-pid.env" ]]; then
    source ${DEPLOYMENT_DIR}/.ssh-agent-pid.env --source-only
    SSH_AGENT_PID=$SSH_AGENT_PID
    kill $SSH_AGENT_PID
    rm ${DEPLOYMENT_DIR}/.ssh-agent-pid.env
    rm ${DEPLOYMENT_DIR}/.ssh-sock.env
    unset SSH_AUTH_SOCK
    unset SSH_AGENT_PID
fi

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
