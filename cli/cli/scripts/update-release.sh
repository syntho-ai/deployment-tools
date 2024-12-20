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
INITIAL_VERSION="$INITIAL_VERSION"
CURRENT_VERSION="$CURRENT_VERSION"
NEW_VERSION="$NEW_VERSION"

INITIAL_RELEASE_DIR="$DEPLOYMENT_DIR/syntho-charts-${INITIAL_VERSION}"
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
        cp -r "$INITIAL_RELEASE_DIR" "$NEW_RELEASE_DIR"
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
    if [[ "$INITIAL_VERSION" != "$NEW_VERSION" ]]; then
        replace_versions_in_values_yaml
    fi
    helm_upgrade
}

replace_versions_in_values_yaml() {
    local RAY_DIR="${NEW_RELEASE_DIR}/helm/ray/chart"
    local RAY_VALUES_PATH="${RAY_DIR}/values-generated.yaml"
    if [ ! -e "$RAY_DIR/values-generated.yaml.bak" ]; then
        echo "it is the first time ray-cluster is being updated for version $NEW_VERSION"
        sed -i.bak "s/${INITIAL_VERSION}/${NEW_VERSION}/g" "$RAY_VALUES_PATH"
    else
        echo "ray cluster is already updated previously for version $NEW_VERSION"
    fi

    local SYNTHO_UI_DIR="${NEW_RELEASE_DIR}/helm/syntho-ui"
    local SYNTHO_VALUES_PATH="${SYNTHO_UI_DIR}/values-generated.yaml"
    if [ ! -e "$SYNTHO_UI_DIR/values-generated.yaml.bak" ]; then
        echo "it is the first time syntho-ui is being updated for version $NEW_VERSION"
        sed -i.bak "s/${INITIAL_VERSION}/${NEW_VERSION}/g" "$SYNTHO_VALUES_PATH"
    else
        echo "syntho-ui is already updated previously for version $NEW_VERSION"
    fi
}

helm_upgrade() {
    local RAY_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/ray/chart"
    local RAY_VALUES_YAML="${RAY_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade ray-cluster $RAY_CHARTS_DIR --values $RAY_VALUES_YAML --namespace syntho --wait --timeout 10m

    local SYNTHO_UI_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/syntho-ui"
    local SYNTHO_UI_VALUES_YAML="${SYNTHO_UI_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade syntho-ui $SYNTHO_UI_CHARTS_DIR --values $SYNTHO_UI_VALUES_YAML --namespace syntho --wait --timeout 10m
}

do_rollout_docker_compose() {
    if [[ "$INITIAL_VERSION" != "$NEW_VERSION" ]]; then
        replace_versions_in_dotenv_file
        replace_versions_in_config_dir
        make_final_images_env_file
        make_list_of_to_be_pulled_images_file
        pull_new_images
    fi

    docker_compose_upgrade
}

replace_versions_in_dotenv_file() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local DOTENV_PATH="${DC_DIR}/.env"
    if [ ! -e "$DC_DIR/.env.bak" ]; then
        echo "it is the first time docker-compose is being updated for version $NEW_VERSION"
        sed -i.bak "s/${INITIAL_VERSION}/${NEW_VERSION}/g" "$DOTENV_PATH"
    else
        echo "docker compose is already updated previously for version $NEW_VERSION"
    fi
}

replace_versions_in_config_dir() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local CONFIG_DIR="${DC_DIR}/config"

    env_files=("images.env" "images-arm.env")
    for env_file in "${env_files[@]}"; do
        if [ ! -e "$CONFIG_DIR/$env_file.bak" ]; then
            echo "it is the first time $env_file is being updated for version $NEW_VERSION"
            sed -i.bak "s/${INITIAL_VERSION}/${NEW_VERSION}/g" "$CONFIG_DIR/$env_file"
        else
            echo "$env_file is already updated previously for version $NEW_VERSION"
        fi
    done
}

make_final_images_env_file() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local CONFIG_DIR="${DC_DIR}/config"
    local FINAL_IMAGES_ENV_PATH="$CONFIG_DIR/final-images.env"

    if [ ! -e "$FINAL_IMAGES_ENV_PATH" ]; then
        local AMD_IMAGES_ENV_PATH="$CONFIG_DIR/images.env"
        local ARM_IMAGES_ENV_PATH="$CONFIG_DIR/images-arm.env"

        echo "Creating '$FINAL_IMAGES_ENV_PATH' by merging AMD and ARM files based on the ARCH variable..."

        if [ "$ARCH" == "amd" ]; then
            cp "$AMD_IMAGES_ENV_PATH" "$FINAL_IMAGES_ENV_PATH"
        elif [ "$ARCH" == "arm" ]; then
            # Create the final-images.env file by merging the two files
            touch "$FINAL_IMAGES_ENV_PATH"
            while IFS= read -r line; do
                var_name=$(echo "$line" | cut -d '=' -f 1)
                if grep -q "^$var_name=" "$ARM_IMAGES_ENV_PATH"; then
                    grep "^$var_name=" "$ARM_IMAGES_ENV_PATH" >> "$FINAL_IMAGES_ENV_PATH"
                else
                    echo "$line" >> "$FINAL_IMAGES_ENV_PATH"
                fi
            done < "$AMD_IMAGES_ENV_PATH"
        else
            echo "Unsupported ARCH value: $ARCH. Please set ARCH to either 'amd' or 'arm'."
            return 1
        fi

        echo "The final-images.env file has been created successfully."
    else
        echo "The final-images.env file already exists."
    fi
}

make_list_of_to_be_pulled_images_file() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local CONFIG_DIR="${DC_DIR}/config"
    local FINAL_IMAGES_ENV_PATH="$CONFIG_DIR/final-images.env"
    local TO_BE_PULLED_IMAGES_FILE="$CONFIG_DIR/to_be_pulled_images.txt"

    # Ensure the final-images.env file exists
    if [ ! -e "$FINAL_IMAGES_ENV_PATH" ]; then
        echo "The final-images.env file does not exist."
        return 1
    fi

    # Clear the to_be_pulled_images.txt file if it exists
    # shellcheck disable=SC2188
    > "$TO_BE_PULLED_IMAGES_FILE"

    # Read the final-images.env file and extract the relevant variables
    local repos=()
    local tags=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([A-Z_]+_IMG_REPO)=(.+)$ ]]; then
            repos+=("${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^([A-Z_]+_IMG_TAG)=(.+)$ ]]; then
            tags+=("${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
        fi
    done < "$FINAL_IMAGES_ENV_PATH"

    # Construct the image repository and tag pairs
    for repo in "${repos[@]}"; do
        repo_var="${repo%%=*}"
        repo_value="${repo#*=}"
        base_var="${repo_var%_IMG_REPO}"
        for tag in "${tags[@]}"; do
            tag_var="${tag%%=*}"
            tag_value="${tag#*=}"
            if [ "$tag_var" == "${base_var}_IMG_TAG" ]; then
                echo "${repo_value}:${tag_value}" >> "$TO_BE_PULLED_IMAGES_FILE"
                break
            fi
        done
    done

    echo "The to_be_pulled_images.txt file has been created successfully."
}

pull_new_images() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    local CONFIG_DIR="${DC_DIR}/config"
    local TO_BE_PULLED_IMAGES_FILE="$CONFIG_DIR/to_be_pulled_images.txt"

    # Ensure the to_be_pulled_images.txt file exists
    if [ ! -e "$TO_BE_PULLED_IMAGES_FILE" ]; then
        echo "The to_be_pulled_images.txt file does not exist."
        return 1
    fi

    # Read the to_be_pulled_images.txt file line by line and echo each line
    while IFS= read -r line; do
        local IMAGE="$line"
        if [[ $IMAGE == *"syntho.azurecr.io"* ]]; then
            echo "Image contains 'syntho.azurecr.io'. DOCKER_CONFIG will be used"
            echo "DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
            DOCKER_CONFIG=$DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
        else
            echo "Image does not contain 'syntho.azurecr.io'. SECONDARY_DOCKER_CONFIG will be used"
            echo "DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE"
            DOCKER_CONFIG=$SECONDARY_DOCKER_CONFIG DOCKER_HOST=$DOCKER_HOST docker pull $IMAGE
        fi
    done < "$TO_BE_PULLED_IMAGES_FILE"
}

docker_compose_upgrade() {
    local DC_DIR="${NEW_RELEASE_DIR}/docker-compose"
    DOCKER_COMPOSE_FILE="$DC_DIR/docker-compose.yaml"
    DOCKER_HOST=$DOCKER_HOST dockercompose -f $DOCKER_COMPOSE_FILE up -d
}

rollout_failure_callback() {
    with_loading "Deployment rollout to new release has been timedout." do_nothing "" "" 2
    with_loading "However, please check pods in syntho namespace, perhaps the deployment is still being rolled out." do_nothing "" "" 2
    with_loading "Contact ${SUPPORT_EMAIL} in case the issue persists." do_nothing "" "" 2
}


with_loading "Fetching desired version if it was not previously rolled out: $NEW_VERSION" check_new_version_or_fetch
with_loading "Rolling out release from $CURRENT_VERSION to $NEW_VERSION" rollout_release 1800 rollout_failure_callback
