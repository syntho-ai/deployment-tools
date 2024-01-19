#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
DOCKER_CONFIG="$DOCKER_CONFIG"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"
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
source $DEPLOYMENT_DIR/.auth.env --source-only
ADMIN_USERNAME="${UI_ADMIN_LOGIN_USERNAME}"
ADMIN_PASSWORD="${UI_ADMIN_LOGIN_PASSWORD}"
ADMIN_EMAIL="${UI_ADMIN_LOGIN_EMAIL}"


LICENSE_KEY="$LICENSE_KEY"
RAY_IMAGE_IMG_REPO="$RAY_IMAGE_IMG_REPO"
RAY_IMAGE_IMG_TAG="$RAY_IMAGE_IMG_TAG"
RAY_CPUS="$RAY_CPUS"
RAY_MEMORY="$RAY_MEMORY"

SYNTHO_UI_CORE_IMG_REPO="$SYNTHO_UI_CORE_IMG_REPO"
SYNTHO_UI_CORE_IMG_VER="$SYNTHO_UI_CORE_IMG_VER"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_VER="$SYNTHO_UI_BACKEND_IMG_VER"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_VER="$SYNTHO_UI_FRONTEND_IMG_VER"


generate_env() {
    local TEMPLATE_FILE="$DC_DIR/.env.tpl"
    local OUTPUT_FILE="$DC_DIR/.env"

    sed "s|{{ LICENSE_KEY }}|$LICENSE_KEY|g; \
         s|{{ RAY_IMAGE_IMG_REPO }}|$RAY_IMAGE_IMG_REPO|g; \
         s|{{ RAY_IMAGE_IMG_TAG }}|$RAY_IMAGE_IMG_TAG|g; \
         s|{{ RAY_CPUS }}|$RAY_CPUS|g; \
         s|{{ RAY_MEMORY }}|$RAY_MEMORY|g; \
         s|{{ SYNTHO_UI_CORE_IMG_REPO }}|$SYNTHO_UI_CORE_IMG_REPO|g; \
         s|{{ SYNTHO_UI_CORE_IMG_VER }}|$SYNTHO_UI_CORE_IMG_VER|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_REPO }}|$SYNTHO_UI_BACKEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_VER }}|$SYNTHO_UI_BACKEND_IMG_VER|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_REPO }}|$SYNTHO_UI_FRONTEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_VER }}|$SYNTHO_UI_FRONTEND_IMG_VER|g; \
         s|{{ ADMIN_EMAIL }}|$ADMIN_EMAIL|g; \
         s|{{ ADMIN_PASSWORD }}|$ADMIN_PASSWORD|g; \
         s|{{ ADMIN_USERNAME }}|$ADMIN_USERNAME|g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"
}

deploy_docker_compose() {
    DOCKER_CONFIG=$DOCKER_CONFIG docker compose -f $DC_DIR/docker-compose.yaml up -d
}

wait_for_frontend_service_health() {
    sleep 2

    is_fe_running() {
        # Check whether Docker container logs contain "started server on 0.0.0.0:3000"
        DOCKER_CONFIG=$DOCKER_CONFIG docker compose -f $DC_DIR/docker-compose.yaml logs frontend 2>&1 | grep -q "started server on 0.0.0.0:3000"
    }


    while ! is_fe_running; do
        sleep 5
    done
}

deploy_syntho_stack() {
    local errors=""

    if ! generate_env >/dev/null 2>&1; then
        errors+=".env generation error for the Syntho Stack\n"
    fi

    if ! deploy_docker_compose >/dev/null 2>&1; then
        errors+="Syntho Stack deployment has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

wait_for_fe_health() {
    local errors=""

    if ! wait_for_frontend_service_health >/dev/null 2>&1; then
        errors+="Syntho Stack health check has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

all_logs() {
    sleep 5

    NAMESPACE="syntho"
    OUTPUT_DIR="/tmp/syntho"
    LOGS_DIR="$SHARED/logs"
    TARBALL="$OUTPUT_DIR/diagnosis-dc.tar.gz"
    rm -rf "$OUTPUT_DIR" "$LOGS_DIR"
    mkdir -p "$OUTPUT_DIR" "$LOGS_DIR"

    services=$(DOCKER_CONFIG=$DOCKER_CONFIG docker compose -f $DC_DIR/docker-compose.yaml ps --services)

    echo "$services" | while IFS= read -r service; do
        echo "Processing logs for service: $service"
        DOCKER_CONFIG=$DOCKER_CONFIG docker compose -f $DC_DIR/docker-compose.yaml logs $service > "$LOGS_DIR/$service.logs"
    done

    tar -czvf "$TARBALL" -C "$LOGS_DIR" .
}

get_all_logs() {

    if ! all_logs >/dev/null 2>&1; then
        errors+="Preparing all logs has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

deployment_failure_callback() {
    with_loading "Please wait until the necessary materials are being prepared for diagnosis" get_all_logs "" "" 2
    with_loading "Please share this file (/tmp/syntho/diagnosis-dc.tar.gz) with support@syntho.ai" do_nothing "" "" 2
}


with_loading "Deploying Syntho Stack" deploy_syntho_stack 600 deployment_failure_callback
with_loading "Waiting for Syntho UI to be healthy" wait_for_fe_health 300 deployment_failure_callback


echo -e '
'"${YELLOW}Syntho stack got deployed. ${GREEN}Please visit:${NC} http://localhost:3000${NC}"'
'"${YELLOW}- Email: $ADMIN_EMAIL${NC}"'
'"${YELLOW}- Password: $ADMIN_PASSWORD${NC}"'
'
