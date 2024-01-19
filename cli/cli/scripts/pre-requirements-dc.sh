#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
DOCKER_CONFIG="$DOCKER_CONFIG"

network_check() {
    sleep 2
    local errors=""

    check() {
        if ping -c 1 google.com &> /dev/null; then
            return 0  # Success, network connection exists
        else
            return 1  # Failure, no network connection
        fi
    }

    if ! check; then
        errors+="There is no active network connection.\n"
    fi

    echo -n "$errors"
}


developer_tools_check() {
    sleep 2
    local errors=""

    # Check if curl or wget exists
    if ! command_exists "curl" && ! command_exists "wget"; then
        errors+="Missing command line tool - curl or wget\n"
    fi

    # Check if docker exists
    if ! command_exists "docker"; then
        errors+="Missing command line tool - docker\n"
    fi

    # Check if tar exists
    if ! command_exists "tar"; then
        errors+="Missing command line tool - tar\n"
    fi

    # Check if awk exists
    if ! command_exists "awk"; then
        errors+="Missing command line tool - awk\n"
    fi

    echo -n "$errors"
}

docker_host_check() {
    sleep 2
    local errors=""

    # Check if DOCKER_CONFIG is set
    if [ -z "$DOCKER_CONFIG" ]; then
        errors+="DOCKER_CONFIG is not set.\n"
    fi

    # Check if DOCKER_CONFIG points to a valid docker host
    if ! DOCKER_CONFIG=$CUSTOM_DOCKER_CONFIG docker info &> /dev/null; then
        errors+="DOCKER_CONFIG does not point to a valid docker host.\n"
    fi

    echo -n "$errors"
}


with_loading "Checking network connectivity" network_check
with_loading "Checking developer tools" developer_tools_check
with_loading "Checking if the given DOCKER_CONFIG points to a valid docker host" docker_host_check
