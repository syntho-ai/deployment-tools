#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only
SUPPORT_EMAIL="$SUPPORT_EMAIL"

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"

source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"
ARCH="$ARCH"
DOCKER_CONFIG="$DOCKER_CONFIG"
SECONDARY_DOCKER_CONFIG="$SECONDARY_DOCKER_CONFIG"
DOCKER_HOST="$DOCKER_HOST"

DEPLOYMENT_TOOLING="$DEPLOYMENT_TOOLING"
CURRENT_VERSION="$CURRENT_VERSION"
NEW_VERSION="$NEW_VERSION"
DEPLOYED="$DEPLOYED"
WITH_CONFIGURATION_CHANGES="$WITH_CONFIGURATION_CHANGES"

CURRENT_RELEASE_DIR="$DEPLOYMENT_DIR/syntho-charts-${CURRENT_VERSION}"
NEW_RELEASE_DIR="$DEPLOYMENT_DIR/syntho-charts-${NEW_VERSION}"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"


check_new_version_or_fetch() {
    local errors=""

    if ! do_check_new_version_or_fetch >/dev/null 2>&1; then
        errors+="Failed to fetching the new release unexpectedly\n"
    fi

    write_and_exit "$errors" "check_new_version_or_fetch"
}

do_check_new_version_or_fetch() {
    if [ ! -d "$NEW_RELEASE_DIR" ] || [ -z "$(ls -A "$NEW_RELEASE_DIR")" ]; then
        cp -r "$CURRENT_RELEASE_DIR" "$NEW_RELEASE_DIR"

        if [ "$DEPLOYMENT_TOOLING" == "helm" ]; then
            DEPLOYED_MARKER=$NEW_RELEASE_DIR/helm/.deployed
        else
            DEPLOYED_MARKER=$NEW_RELEASE_DIR/docker-compose/.deployed
        fi

        # since this is a new release, and copied from the current release, deployed marker is
        # deleted
        rm -rf $DEPLOYED_MARKER
    fi
}

rollout_release() {
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/rollout_release.log"

    if ! do_rollout_release >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Failed to rolling out the new release unexpectedly\n"
    fi

    write_and_exit "$errors" "rollout_release"
}

do_rollout_release() {
    if [ "$DEPLOYMENT_TOOLING" == "helm" ]; then
        do_rollout_kubernetes
    else
        do_rollout_docker_compose
    fi
}

do_rollout_kubernetes() {
    if [[ "$DEPLOYED" == "true" ]]; then
        echo "$NEW_VERSION got already deployed previously. Skipping the altering the envs phase."
    else
        echo "$NEW_VERSION isn't deployed previously. Altering the envs."
        clean_generated_values
        replace_images_in_env_files
        if [[ "$WITH_CONFIGURATION_CHANGES" == "true" ]]; then
            copy_new_envs
        fi
        generate_new_values_generated_files
    fi
    helm_upgrade
}

clean_generated_values() {
    local GENERATED_VALUES_FOR_RAY_PATH=$NEW_RELEASE_DIR/helm/ray/values-generated.yaml
    local GENERATED_VALUES_FOR_SYNTHO_UI_PATH=$NEW_RELEASE_DIR/helm/syntho-ui/values-generated.yaml

    rm -rf $GENERATED_VALUES_FOR_RAY_PATH
    rm -rf $GENERATED_VALUES_FOR_SYNTHO_UI_PATH
}

replace_images_in_env_files() {
    local ENV_FILE=$NEW_RELEASE_DIR/$DEPLOYMENT_TOOLING/envs/.env
    local IMAGES_ENV_FILE=$NEW_RELEASE_DIR/$DEPLOYMENT_TOOLING/envs/.images.env
    local IMAGES_ARM_ENV_FILE=$NEW_RELEASE_DIR/$DEPLOYMENT_TOOLING/envs/.images-arm.env

    # Update image tags in .images.env
    sed -i.bak -E "/_IMG_TAG=/ { /BUSYBOX_IMG_TAG/! s/$CURRENT_VERSION/$NEW_VERSION/g; }" "$IMAGES_ENV_FILE"

    # Update image tags in .images-arm.env
    sed -i.bak -E "/_IMG_TAG=/ { /BUSYBOX_IMG_TAG/! s/$CURRENT_VERSION/$NEW_VERSION/g; }" "$IMAGES_ARM_ENV_FILE"

    # Update VERSION in .env
    sed -i.bak -E "s/VERSION=$CURRENT_VERSION/VERSION=$NEW_VERSION/g" "$ENV_FILE"

    # Clean up backup files
    rm -rf "$IMAGES_ENV_FILE.bak"
    rm -rf "$IMAGES_ARM_ENV_FILE.bak"
    rm -rf "$ENV_FILE.bak"
}

copy_new_envs() {
    local NEW_ENV_DIR_FROM=$DEPLOYMENT_DIR/temp-compatibility-check/syntho-$NEW_VERSION/$DEPLOYMENT_TOOLING/new_envs
    local NEW_ENV_DIR_TO=$NEW_RELEASE_DIR/$DEPLOYMENT_TOOLING
    cp -r "$NEW_ENV_DIR_FROM" "$NEW_ENV_DIR_TO"
}

generate_new_values_generated_files() {
    local ALL_ENV_FILES_DIR=$NEW_RELEASE_DIR/helm/envs
    local ROOT_ENV_FILE="$ALL_ENV_FILES_DIR/.env"
    # shellcheck disable=SC2155
    local ARCH=$(grep -E '^ARCH=' "$ROOT_ENV_FILE" | cut -d '=' -f 2)

    # Use find to iterate over all .env files in the directory
    # shellcheck disable=SC2044
    for env_file in $(find "$ALL_ENV_FILES_DIR" -name "*.env" -type f); do
        # Skip .images-arm.env files
        if [[ "$env_file" == *".images-arm.env" ]]; then
            echo "Skipping $env_file"
            continue
        fi

        echo "env_file is: $env_file"
        # Check if the file exists (find ensures this, but let's keep it for safety)
        if [[ -f "$env_file" ]]; then
            echo "sourcing $env_file"
            # shellcheck disable=SC1090
            source "$env_file" --source-only
        fi
    done

    # Override image versions if it is ARM chip
    if [[ "$ARCH" == "arm" ]]; then
        # shellcheck disable=SC1090
        local ARM_ENV_FILE="$ALL_ENV_FILES_DIR/.images-arm.env"
        # shellcheck disable=SC1090
        source $ARM_ENV_FILE --source-only
    fi

    ## WITH_CONFIGURATION_CHANGES START ##
    # here we will override the original env variables from previous release with the new config
    # a.k.a with new answers from the user
    if [[ "$WITH_CONFIGURATION_CHANGES" == "true" ]]; then
        echo "WITH_CONFIGURATION_CHANGES: there are config changes, new env vars will be exposed, the old ones will be overridden"

        local ALL_NEW_ENV_FILES_DIR=$NEW_RELEASE_DIR/helm/new_envs
        # shellcheck disable=SC2044
        for env_file in $(find "$ALL_NEW_ENV_FILES_DIR" -name "*.env" -type f); do
            # Skip .images*.env files
            if [[ "$env_file" == *".images-arm.env" || "$env_file" == *".images.env" ]]; then
                echo "Skipping $env_file"
                # we already processed .images*.env above, here we are only processing config
                # changes if any
                continue
            fi

            echo "env_file is: $env_file"
            # Check if the file exists (find ensures this, but let's keep it for safety)
            if [[ -f "$env_file" ]]; then
                echo "sourcing $env_file"
                # shellcheck disable=SC1090
                source "$env_file" --source-only
            fi
        done
    fi
    ## WITH_CONFIGURATION_CHANGES END ##

    # Backwards-compatibility start
    # TODO later, directly use env vars in .tpl files - tech debt
    # shellcheck disable=SC2034
    UI_LOGIN_EMAIL="${UI_ADMIN_LOGIN_EMAIL}"
    # shellcheck disable=SC2034
    UI_LOGIN_PASSWORD="${UI_ADMIN_LOGIN_PASSWORD}"
    # Backwards-compatibility end

    # Function to process template files
    process_template_file() {
        local TEMPLATE_FILE=$1
        local VALUES_FILE=$2

        # Create a copy of the template file to work with
        cp "$TEMPLATE_FILE" "$VALUES_FILE"

        # Iterate over all environment variables
        for VAR in $(compgen -v); do
            echo "processing: $VAR: ${!VAR}"
            # Check the operating system
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS uses BSD sed
                sed -i '' "s|{{ $VAR }}|${!VAR}|g" "$VALUES_FILE"
            else
                # Linux uses GNU sed
                sed -i "s|{{ $VAR }}|${!VAR}|g" "$VALUES_FILE"
            fi
        done
    }

    # Process ray generated-values.yaml
    local RAY_TEMPLATE_FILE="$NEW_RELEASE_DIR/helm/ray/values.yaml.tpl"
    local RAY_VALUES_FILE="$NEW_RELEASE_DIR/helm/ray/values-generated.yaml"
    process_template_file "$RAY_TEMPLATE_FILE" "$RAY_VALUES_FILE"

    # Process syntho-ui generated-values.yaml
    local SYNTHO_UI_TEMPLATE_FILE="$NEW_RELEASE_DIR/helm/syntho-ui/values.yaml.tpl"
    local SYNTHO_UI_VALUES_FILE="$NEW_RELEASE_DIR/helm/syntho-ui/values-generated.yaml"
    process_template_file "$SYNTHO_UI_TEMPLATE_FILE" "$SYNTHO_UI_VALUES_FILE"
}

helm_upgrade() {
    local RAY_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/ray"
    local RAY_VALUES_YAML="${RAY_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade ray-cluster $RAY_CHARTS_DIR --values $RAY_VALUES_YAML --namespace syntho --wait --timeout 10m

    local SYNTHO_UI_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/syntho-ui"
    local SYNTHO_UI_VALUES_YAML="${SYNTHO_UI_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade syntho-ui $SYNTHO_UI_CHARTS_DIR --values $SYNTHO_UI_VALUES_YAML --namespace syntho --wait --timeout 10m

    marker=$NEW_RELEASE_DIR/helm/.deployed
    touch $marker
}

do_rollout_docker_compose() {
    if [[ "$DEPLOYED" == "true" ]]; then
        echo "$NEW_VERSION got already deployed previously. Skipping the altering the envs phase."
    else
        echo "$NEW_VERSION isn't deployed previously. Altering the envs."
        clean_generated_env
        replace_images_in_env_files
        generate_new_env_for_docker
        pull_new_images_for_docker
    fi

    docker_compose_upgrade
}

clean_generated_env() {
    local GENERATED_ENV_PATH=$NEW_RELEASE_DIR/docker-compose/.env
    rm -rf $GENERATED_ENV_PATH
}

generate_new_env_for_docker() {
    local ALL_ENV_FILES_DIR=$NEW_RELEASE_DIR/docker-compose/envs
    local ROOT_ENV_FILE="$ALL_ENV_FILES_DIR/.env"
    # shellcheck disable=SC2155
    local ARCH=$(grep -E '^ARCH=' "$ROOT_ENV_FILE" | cut -d '=' -f 2)

    # Use find to iterate over all .env files in the directory
    # shellcheck disable=SC2044
    for env_file in $(find "$ALL_ENV_FILES_DIR" -name "*.env" -type f); do
        # Skip .images-arm.env files
        if [[ "$env_file" == *".images-arm.env" ]]; then
            echo "Skipping $env_file"
            continue
        fi

        echo "env_file is: $env_file"
        # Check if the file exists (find ensures this, but let's keep it for safety)
        if [[ -f "$env_file" ]]; then
            echo "sourcing $env_file"
            # shellcheck disable=SC1090
            source "$env_file" --source-only
        fi
    done

    # Override image versions if it is ARM chip
    if [[ "$ARCH" == "arm" ]]; then
        # shellcheck disable=SC1090
        local ARM_ENV_FILE="$ALL_ENV_FILES_DIR/.images-arm.env"
        # shellcheck disable=SC1090
        source $ARM_ENV_FILE --source-only
    fi

    # Backwards-compatibility start
    # FIXME later, directly use env vars in .tpl files
    # shellcheck disable=SC2034
    ADMIN_USERNAME="${UI_ADMIN_LOGIN_USERNAME}"
    # shellcheck disable=SC2034
    ADMIN_PASSWORD="${UI_ADMIN_LOGIN_PASSWORD}"
    # shellcheck disable=SC2034
    ADMIN_EMAIL="${UI_ADMIN_LOGIN_EMAIL}"
    # Backwards-compatibility end

    # Function to process template files
    process_template_file() {
        local TEMPLATE_FILE=$1
        local VALUES_FILE=$2

        # Create a copy of the template file to work with
        cp "$TEMPLATE_FILE" "$VALUES_FILE"

        # Iterate over all environment variables
        for VAR in $(compgen -v); do
            echo "processing: $VAR: ${!VAR}"
            # Check the operating system
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS uses BSD sed
                sed -i '' "s|{{ $VAR }}|${!VAR}|g" "$VALUES_FILE"
            else
                # Linux uses GNU sed
                sed -i "s|{{ $VAR }}|${!VAR}|g" "$VALUES_FILE"
            fi
        done
    }

    # Process .env for docker compose
    local TEMPLATE_FILE="$NEW_RELEASE_DIR/docker-compose/.env.tpl"
    local ENV_FILE="$NEW_RELEASE_DIR/docker-compose/.env"
    process_template_file "$TEMPLATE_FILE" "$ENV_FILE"
}

pull_new_images_for_docker() {
    local MAIN_ENV_FILE="${NEW_RELEASE_DIR}/docker-compose/envs/.env"

    # Extract the values of the specific environment variables
    # shellcheck disable=SC2155
    local DOCKER_HOST=$(grep -E '^DOCKER_HOST=' "$MAIN_ENV_FILE" | cut -d '=' -f 2-)
    # shellcheck disable=SC2155
    local DOCKER_CONFIG=$(grep -E '^DOCKER_CONFIG=' "$MAIN_ENV_FILE" | cut -d '=' -f 2-)
    # shellcheck disable=SC2155
    local SECONDARY_DOCKER_CONFIG=$(grep -E '^SECONDARY_DOCKER_CONFIG=' "$MAIN_ENV_FILE" | cut -d '=' -f 2-)

    local GENERATED_ENV_FILE="${NEW_RELEASE_DIR}/docker-compose/.env"


    echo "PULLING IMAGES....\n"
    for line in $(cat "$GENERATED_ENV_FILE"); do
        # Check if the line contains an environment variable ending with _IMAGE
        if [[ "$line" == *"_IMAGE="* ]]; then
            # Extract and print the value of the environment variable
            # shellcheck disable=SC2155
            local IMAGE=$(echo "$line" | cut -d '=' -f 2)
            echo "image to be pulled: $IMAGE"

            if [[ $IMAGE == *"syntho.azurecr.io"* ]]; then
                echo "Image contains 'syntho.azurecr.io'. DOCKER_CONFIG will be used"
                echo "DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
                DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
            else
                echo "Image does not contain 'syntho.azurecr.io'. SECONDARY_DOCKER_CONFIG will be used"
                echo "DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
                DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
            fi

        fi
    done
    echo "IMAGES HAVE BEEN PULLED!\n"
}

docker_compose_upgrade() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local DOCKER_COMPOSE_FILE="$DC_DIR/docker-compose.yaml"
    DOCKER_HOST=$DOCKER_HOST dockercompose -f $DOCKER_COMPOSE_FILE up -d
}

rollout_failure_callback() {
    with_loading "Deployment rollout to new release has been timedout." do_nothing "" "" 2
    with_loading "However, please check pods in syntho namespace, perhaps the deployment is still being rolled out." do_nothing "" "" 2
    with_loading "Contact ${SUPPORT_EMAIL} in case the issue persists." do_nothing "" "" 2
}


with_loading "Fetching desired version if it was not previously rolled out: $NEW_VERSION" check_new_version_or_fetch
with_loading "Rolling out release from $CURRENT_VERSION to $NEW_VERSION" rollout_release 1800 rollout_failure_callback
