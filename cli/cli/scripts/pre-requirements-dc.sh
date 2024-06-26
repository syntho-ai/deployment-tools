#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
DOCKER_HOST="$DOCKER_HOST"
DOCKER_SSH_USER_PRIVATE_KEY="$DOCKER_SSH_USER_PRIVATE_KEY"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"

docker_info() {
    echo "command: DOCKER_HOST=$DOCKER_HOST docker info"
    DOCKER_HOST=$DOCKER_HOST docker info
}

network_check() {
    sleep 2
    local errors=""
    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/network_check.log"
    echo "network_check has been started" >> $SYNTHO_CLI_PROCESS_LOGS

    check() {
        # ICPM traffic is blocked on CI env, therefore we used curl to mimic ping
        if curl -s --head https://www.google.com/ >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
            echo "ping to google.com is successful"
            return 0
        else
            echo "ping to google.com is failure"
            return 1
        fi
    }

    if ! check >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="There is no active network connection.\n"
    fi

    write_and_exit "$errors" "network_check"
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

    # Check if grep exists
    if ! command_exists "grep"; then
        errors+="Missing command line tool - grep\n"
    fi

    # Check if awk exists
    if ! command_exists "awk"; then
        errors+="Missing command line tool - awk\n"
    fi

    # Check if jq exists
    if ! command_exists "jq"; then
        errors+="Missing command line tool - jq\n"
    fi

    # Check if docker-compose exists
    if ! command_exists "dockercompose"; then
        errors+="Missing command line tool - docker-compose\n"
    fi

    if [[ $DOCKER_HOST == ssh://* ]] && [[ -n $DOCKER_SSH_USER_PRIVATE_KEY ]]; then
        # Check if ssh-agent exists
        if ! command_exists "ssh-agent"; then
            errors+="Missing command line tool - ssh-agent (required for remote docker deployments)\n"
        fi

        # Check if scp exists
        if ! command_exists "scp"; then
            errors+="Missing command line tool - scp (required for remote docker deployments)\n"
        fi
    fi

    write_and_exit "$errors" "developer_tools_check"
}

docker_host_check() {
    sleep 2
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/docker_host_check.log"
    echo "docker_host_check has been started" >> $SYNTHO_CLI_PROCESS_LOGS

    # Check if DOCKER_HOST is set
    if [ -z "$DOCKER_HOST" ]; then
        errors+="DOCKER_HOST is not set.\n"
    fi

    CHECK_ARCH=true
    if ! docker_info >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="DOCKER_HOST does not point to a valid docker host ($DOCKER_HOST).\n"
        CHECK_ARCH=false
    fi

    if $CHECK_ARCH; then
        VERSION_INFO=$(DOCKER_HOST=$DOCKER_HOST docker version)
        CLIENT_ARCH=$(echo "$VERSION_INFO" | grep "OS/Arch" | awk 'NR==1{print $2}' | awk -F'/' '{print $2}')
        SERVER_ARCH=$(echo "$VERSION_INFO" | grep "OS/Arch" | awk 'NR==2{print $2}' | awk -F'/' '{print $2}')

        if [[ $CLIENT_ARCH != "$SERVER_ARCH" ]]; then
            errors+="Docker client($CLIENT_ARCH) and server($SERVER_ARCH) architecture isn't compatible with each other.\n"
        fi
    fi

    if [ -z "$errors" ]; then
        cat << EOF > "$DEPLOYMENT_DIR/.docker-arch.env"
CLIENT_ARCH=$CLIENT_ARCH
SERVER_ARCH=$SERVER_ARCH
EOF
    fi

    write_and_exit "$errors" "docker_host_check"
}


with_loading "Checking developer tools" developer_tools_check
with_loading "Checking network connectivity" network_check

if [[ $DOCKER_HOST == ssh://* ]] && [[ -n $DOCKER_SSH_USER_PRIVATE_KEY ]]; then
    eval "$(ssh-agent -s)"
    SSH_AGENT_PID=$SSH_AGENT_PID
    ssh-add $DOCKER_SSH_USER_PRIVATE_KEY
    SSH_AUTH_SOCK=$SSH_AUTH_SOCK
fi

with_loading "Checking if the given docker host points to a valid docker host and it is compatible with the cli" docker_host_check
if [[ -n $SSH_AGENT_PID ]]; then
    cat << EOF > "$DEPLOYMENT_DIR/.ssh-agent-pid.env"
SSH_AGENT_PID=$SSH_AGENT_PID
EOF

    cat << EOF > "$DEPLOYMENT_DIR/.ssh-sock.env"
export SSH_AUTH_SOCK=$SSH_AUTH_SOCK
EOF
fi
