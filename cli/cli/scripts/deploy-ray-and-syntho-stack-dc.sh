#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only
SUPPORT_EMAIL="$SUPPORT_EMAIL"

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
DOCKER_CONFIG="$DOCKER_CONFIG"
SECONDARY_DOCKER_CONFIG="$SECONDARY_DOCKER_CONFIG"
DOCKER_HOST="$DOCKER_HOST"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"
USE_TRUSTED_REGISTRY="$USE_TRUSTED_REGISTRY"
USE_OFFLINE_REGISTRY="$USE_OFFLINE_REGISTRY"
source $DEPLOYMENT_DIR/.config.env --source-only
source $DEPLOYMENT_DIR/.images.env --source-only
ARCH="$ARCH"
if [[ "$ARCH" == "arm" ]]; then
    source $DEPLOYMENT_DIR/.images-arm.env --source-only
fi
source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
DC_DIR="$DC_DIR"
source $DEPLOYMENT_DIR/.resources.env --source-only
SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"
source $DEPLOYMENT_DIR/.auth.env --source-only
# shellcheck disable=SC2034
ADMIN_USERNAME="${UI_ADMIN_LOGIN_USERNAME}"
ADMIN_PASSWORD="${UI_ADMIN_LOGIN_PASSWORD}"
ADMIN_EMAIL="${UI_ADMIN_LOGIN_EMAIL}"

SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/trusted_image_registry_usage.log"
echo "USE_TRUSTED_REGISTRY: $USE_TRUSTED_REGISTRY" >> $SYNTHO_CLI_PROCESS_LOGS
if [[ "$USE_TRUSTED_REGISTRY" == "true" ]]; then
    echo "using trusted image registry instead" >> $SYNTHO_CLI_PROCESS_LOGS
    PREPULL_IMAGES_DIR="$PREPULL_IMAGES_DIR"
    # Read the .image-trusted.env file line by line
    while IFS='=' read -r key value; do
        # Remove the "TRUSTED_" prefix
        new_key=${key#TRUSTED_}
        # Export the variable with the new name
        export $new_key="$value"
    done < $PREPULL_IMAGES_DIR/.images-trusted.env
    echo "env vars are overridden with trusted registry info" >> $SYNTHO_CLI_PROCESS_LOGS
fi

SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/offline_image_registry_usage.log"
echo "USE_OFFLINE_REGISTRY: $USE_OFFLINE_REGISTRY" >> $SYNTHO_CLI_PROCESS_LOGS
if [[ "$USE_OFFLINE_REGISTRY" == "true" ]]; then
    echo "using offline image registry instead" >> $SYNTHO_CLI_PROCESS_LOGS
    ACTIVATE_OFFLINE_MODE_DIR="$ACTIVATE_OFFLINE_MODE_DIR"
    ACTIVATE_OFFLINE_MODE_ARCHIVE_PATH="$ACTIVATE_OFFLINE_MODE_ARCHIVE_PATH"
    # Read the .image-offline.env file line by line
    while IFS='=' read -r key value; do
        # Remove the "OFFLINE_" prefix
        new_key=${key#OFFLINE_}
        # Export the variable with the new name
        export $new_key="$value"
    done < $ACTIVATE_OFFLINE_MODE_DIR/.images-offline.env
    echo "env vars are overridden with offline registry info" >> $SYNTHO_CLI_PROCESS_LOGS
fi


LICENSE_KEY="$LICENSE_KEY"
DOMAIN="$DOMAIN"
RAY_IMAGE_IMG_REPO="$RAY_IMAGE_IMG_REPO"
RAY_IMAGE_IMG_TAG="$RAY_IMAGE_IMG_TAG"
RAY_CPUS="$RAY_CPUS"
RAY_MEMORY="$RAY_MEMORY"

SYNTHO_UI_CORE_IMG_REPO="$SYNTHO_UI_CORE_IMG_REPO"
SYNTHO_UI_CORE_IMG_TAG="$SYNTHO_UI_CORE_IMG_TAG"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_TAG="$SYNTHO_UI_BACKEND_IMG_TAG"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_TAG="$SYNTHO_UI_FRONTEND_IMG_TAG"
POSTGRES_IMG_REPO="$POSTGRES_IMG_REPO"
POSTGRES_IMG_TAG="$POSTGRES_IMG_TAG"
REDIS_IMG_REPO="$REDIS_IMG_REPO"
REDIS_IMG_TAG="$REDIS_IMG_TAG"

if [[ -f "${DEPLOYMENT_DIR}/.ssh-sock.env" ]] && [[ -f "${DEPLOYMENT_DIR}/.ssh-agent-pid.env" ]]; then
    source ${DEPLOYMENT_DIR}/.ssh-sock.env
    IS_REMOTE_DOCKER="true"
else
    IS_REMOTE_DOCKER="false"
fi

source ${DEPLOYMENT_DIR}/.docker-arch.env
CLIENT_ARCH="$CLIENT_ARCH"
SERVER_ARCH="$SERVER_ARCH"

DRY_RUN="$DRY_RUN"


generate_env() {
    local TEMPLATE_FILE="$DC_DIR/.env.tpl"
    local OUTPUT_FILE="$DC_DIR/.env"

    # Create a copy of the template file to work with
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

    # Iterate over all environment variables
    for VAR in $(compgen -v); do
      echo "processing: $VAR: ${!VAR}"
      # Check the operating system
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses BSD sed
        sed -i '' "s|{{ $VAR }}|${!VAR}|g" "$OUTPUT_FILE"
      else
        # Linux uses GNU sed
        sed -i "s|{{ $VAR }}|${!VAR}|g" "$OUTPUT_FILE"
      fi
    done
}

deploy_docker_compose() {
    DOCKER_FILE="-f $DC_DIR/docker-compose.yaml"

    if [ "$IS_REMOTE_DOCKER" = "true" ]; then
        SSH_ENDPOINT=${DOCKER_HOST#*//}
        ssh $SSH_ENDPOINT mkdir -p /tmp/syntho
        scp $DC_DIR/postgres/docker-postgres-entrypoint.sh $SSH_ENDPOINT:/tmp/syntho/docker-postgres-entrypoint.sh
        ssh $SSH_ENDPOINT chmod +x /tmp/syntho/docker-postgres-entrypoint.sh

        generate_override_remote_file "$DC_DIR/docker-compose-override-remote.yaml"
        DOCKER_FILE+=" -f $DC_DIR/docker-compose-override-remote.yaml"

        if [[ $CLIENT_ARCH == "arm64" && $SERVER_ARCH == "amd64" ]]; then
            generate_override_amd64_file "$DC_DIR/docker-compose-override-amd64.yaml"
            DOCKER_FILE+=" -f $DC_DIR/docker-compose-override-amd64.yaml"
        fi
    fi



    local DOCKER_FILE_EXTENSION
    DOCKER_FILE_EXTENSION="$(echo "$DOCKER_FILE")"

    # shellcheck disable=SC2207
    IMAGES=($(DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST dockercompose $DOCKER_FILE_EXTENSION config | grep "image:" | awk '{print $2}' | sort -u))
    for IMAGE in "${IMAGES[@]}"; do
        echo "Pulling Image: $IMAGE"
        if [[ $IMAGE == *"syntho.azurecr.io"* ]]; then
          echo "Image contains 'syntho.azurecr.io'. DOCKER_CONFIG will be used"
            echo "DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
            DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
        else
          echo "Image does not contain 'syntho.azurecr.io'. SECONDARY_DOCKER_CONFIG will be used"
            echo "DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
            DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        COMPOSE_CONFIG=$(DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST dockercompose $DOCKER_FILE_EXTENSION config)
        echo "COMPOSE CONFIG:\n$COMPOSE_CONFIG"
    else
        DOCKER_HOST=$DOCKER_HOST dockercompose $DOCKER_FILE_EXTENSION up -d
    fi
}

generate_override_remote_file() {
    local fdir="$1"
    cat << EOF > "$fdir"
version: '3'
services:
  postgres:
    volumes:
      - database-data:/var/lib/postgresql/data/
      - /tmp/syntho/docker-postgres-entrypoint.sh:/docker-entrypoint-initdb.d/docker-postgres-entrypoint.sh
EOF
}

generate_override_amd64_file() {
    local fdir="$1"
    cat << EOF > "$fdir"
version: '3'
services:
  postgres:
    platform: linux/amd64
EOF
}

wait_for_frontend_service_health() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY_RUN is enabled. Skipping actual health check and simulating success."
        sleep 5
        return 0
    fi

    sleep 2

    is_fe_running() {
        # Check whether Docker container logs contain "started server on 0.0.0.0:3000"
        DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST dockercompose -f $DC_DIR/docker-compose.yaml logs frontend 2>&1 | grep -q "started server on 0.0.0.0:3000"
    }


    while ! is_fe_running; do
        sleep 5
    done
}

deploy_syntho_stack() {
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/deploy_syntho_stack.log"
    echo "deploy_syntho_stack has been started" >> $SYNTHO_CLI_PROCESS_LOGS

    if ! generate_env >/dev/null 2>&1; then
        errors+=".env generation error for the Syntho Stack\n"
    fi

    if ! deploy_docker_compose >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Syntho Stack deployment has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "deploy_syntho_stack"
}

wait_for_fe_health() {
    local errors=""

    if ! wait_for_frontend_service_health >/dev/null 2>&1; then
        errors+="Syntho Stack health check has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "wait_for_fe_health"
}

all_logs() {
    sleep 5

    OUTPUT_DIR="/tmp/syntho"
    LOGS_DIR="$SHARED/logs"
    TARBALL="$OUTPUT_DIR/diagnosis-dc.tar.gz"
    rm -rf "$OUTPUT_DIR" "$LOGS_DIR"
    mkdir -p "$OUTPUT_DIR" "$LOGS_DIR"

    services=$(DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST dockercompose -f $DC_DIR/docker-compose.yaml ps --services)

    echo "$services" | while IFS= read -r service; do
        echo "Processing logs for service: $service"
        DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST dockercompose -f $DC_DIR/docker-compose.yaml logs $service > "$LOGS_DIR/$service.log"
    done

    tar -czvf "$TARBALL" -C "$LOGS_DIR" .
}

get_all_logs() {

    if ! all_logs >/dev/null 2>&1; then
        errors+="Preparing all logs has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "get_all_logs"
}

deployment_failure_callback() {
    with_loading "Please wait until the necessary materials are being prepared for diagnosis" get_all_logs "" "" 2
    with_loading "Please share this file (/tmp/syntho/diagnosis-dc.tar.gz) with ${SUPPORT_EMAIL}" do_nothing "" "" 2
}

deploy_offline_image_registry() {
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/deploy_offline_image_registry.log"
    echo "deploy_offline_image_registry has been started" >> $SYNTHO_CLI_PROCESS_LOGS

    if ! do_deploy_offline_image_registry >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Deploying an offline image registry process has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "deploy_offline_image_registry"
}

do_deploy_offline_image_registry() {
    AVAILABLE_PORT=$(grep AVAILABLE_PORT $ACTIVATE_OFFLINE_MODE_DIR/.env | cut -d '=' -f2)
    if [ "$IS_REMOTE_DOCKER" = "true" ]; then
        SSH_ENDPOINT=${DOCKER_HOST#*//}

        echo "deployment dir: $DEPLOYMENT_DIR"
        echo "available port: $AVAILABLE_PORT"
        echo "offline archive: $ACTIVATE_OFFLINE_MODE_ARCHIVE_PATH"
        echo "docker config: $DOCKER_CONFIG"
        echo "docker host: $DOCKER_HOST"
        echo "ssh endpoint: $SSH_ENDPOINT"
        # echo "sleeping forever"
        # sleep 999999999

        ssh $SSH_ENDPOINT mkdir -p /tmp/syntho
        ssh $SSH_ENDPOINT rm -rf /tmp/syntho/activate-offline-mode
        ssh $SSH_ENDPOINT mkdir -p /tmp/syntho/activate-offline-mode
        scp $ACTIVATE_OFFLINE_MODE_ARCHIVE_PATH $SSH_ENDPOINT:/tmp/syntho/activate-offline-mode/activate-offline-mode.tar.gz
        ssh $SSH_ENDPOINT tar -xzf /tmp/syntho/activate-offline-mode/activate-offline-mode.tar.gz -C /tmp/syntho/activate-offline-mode/

        ssh $SSH_ENDPOINT docker load -i /tmp/syntho/activate-offline-mode/syntho-offline-registry.tar
        ssh $SSH_ENDPOINT mkdir -p /tmp/syntho/activate-offline-mode/registry
        ssh $SSH_ENDPOINT tar -xzf /tmp/syntho/activate-offline-mode/registry-lib.tar.gz -C /tmp/syntho/activate-offline-mode/registry

        ssh $SSH_ENDPOINT docker run -d -p $AVAILABLE_PORT:5000 --name syntho-offline-registry syntho-offline-registry:latest
        ssh $SSH_ENDPOINT docker cp /tmp/syntho/activate-offline-mode/registry syntho-offline-registry:/var/lib/
        # echo "sleeping forever"
        # sleep 999999999
    else
        mkdir -p /tmp/syntho
        rm -rf /tmp/syntho/activate-offline-mode
        mkdir -p /tmp/syntho/activate-offline-mode
        cp $ACTIVATE_OFFLINE_MODE_ARCHIVE_PATH /tmp/syntho/activate-offline-mode/activate-offline-mode.tar.gz
        tar -xzf /tmp/syntho/activate-offline-mode/activate-offline-mode.tar.gz -C /tmp/syntho/activate-offline-mode/

        DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker load -i /tmp/syntho/activate-offline-mode/syntho-offline-registry.tar
        mkdir -p /tmp/syntho/activate-offline-mode/registry
        tar -xzf /tmp/syntho/activate-offline-mode/registry-lib.tar.gz -C /tmp/syntho/activate-offline-mode/registry

        DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker run -d -p $AVAILABLE_PORT:5000 --name syntho-offline-registry syntho-offline-registry:latest
        DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker cp /tmp/syntho/activate-offline-mode/registry syntho-offline-registry:/var/lib/
    fi
}


if [[ "$USE_OFFLINE_REGISTRY" == "true" ]]; then
    with_loading "Deploying offline image registry with necessary images in it" deploy_offline_image_registry
fi

with_loading "Deploying Syntho Stack" deploy_syntho_stack 1800 deployment_failure_callback
with_loading "Waiting for Syntho UI to be healthy" wait_for_fe_health 300 deployment_failure_callback

if [[ -f "${DEPLOYMENT_DIR}/.ssh-sock.env" ]] && [[ -f "${DEPLOYMENT_DIR}/.ssh-agent-pid.env" ]]; then
    source ${DEPLOYMENT_DIR}/.ssh-agent-pid.env --source-only
    SSH_AGENT_PID=$SSH_AGENT_PID
    kill $SSH_AGENT_PID
    rm ${DEPLOYMENT_DIR}/.ssh-agent-pid.env
    rm ${DEPLOYMENT_DIR}/.ssh-sock.env
    unset SSH_AUTH_SOCK
    unset SSH_AGENT_PID
fi

echo -e '
'"${YELLOW}Syntho stack got deployed.${NC} ${GREEN}Please visit:${NC} http://${DOMAIN}:3000${NC}"'
'"${YELLOW}Make sure the port (3000) on the docker host is reachable.${NC}"'
'"${YELLOW}- Email: $ADMIN_EMAIL${NC}"'
'"${YELLOW}- Password: $ADMIN_PASSWORD${NC}"'
'
