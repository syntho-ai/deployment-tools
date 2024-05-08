#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

OFFLINE_REGISTRY="$OFFLINE_REGISTRY"
AVAILABLE_PORT="$AVAILABLE_PORT"
VERSION="$VERSION"
ARCH="$ARCH"
DOCKER_CONFIG="$DOCKER_CONFIG"

CHARTS_RELEASE_ASSET_URL=https://github.com/syntho-ai/syntho-charts/archive/refs/tags/${VERSION}.tar.gz
TARBALL_DESTINATION=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}.tar.gz
EXTRACT_LOCATION=${DEPLOYMENT_DIR}


SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"

download_release() {
    local errors=""

    if ! command_exists "curl"; then
        if ! curl -LJ "${CHARTS_RELEASE_ASSET_URL}" -o "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
            errors+="Failed to download release using curl. Make sure that the given version exists.\n"
        fi
    else
        if ! wget "${CHARTS_RELEASE_ASSET_URL}" -O "${TARBALL_DESTINATION}" >/dev/null 2>&1; then
            errors+="Failed to download release using wget. Make sure that the given version exists.\n"
        fi
    fi

    write_and_exit "$errors" "download_release"
}

extract_release() {
    sleep 1
    local errors=""


    if ! tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}" >/dev/null 2>&1; then
        errors+="Failed to extract the release\n"
    fi

    RELEASE_CONFIG_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/helm/config
    cp ${RELEASE_CONFIG_DIR}/images.env ${DEPLOYMENT_DIR}/.images.env
    cp ${RELEASE_CONFIG_DIR}/images-arm.env ${DEPLOYMENT_DIR}/.images-arm.env

    write_and_exit "$errors" "extract_release"
}

create_offline_image_registry() {
    sleep 1
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/create_offline_image_registry.log"


    if ! run_registry2 >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when running the registry:2 image\n"
    fi

    if ! prepare_final_versions >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when preparing final image versions\n"
    fi

    if ! prepare_offline_images >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when preparing offline image versions\n"
    fi

    if ! pull_images >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Pulling images into the offline registry has been unexpectedly failed\n"
    fi

    if ! archive_offline_registry >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Archiving the offline registry has been unexpectedly failed\n"
    fi

    if ! delete_registry2 >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when deleting the syntho-offline-registry container\n"
    fi

    write_and_exit "$errors" "create_offline_image_registry"
}

run_registry2() {
    echo "deploying registry:2 image locally"
    DOCKER_CONFIG=$DOCKER_CONFIG docker run -d -p $AVAILABLE_PORT:5000 --name syntho-offline-registry -v /var/lib/registry registry:2

    # give some time for docker to start the process
    sleep 5

    # Verify if Docker container is running
    if [ "$(DOCKER_CONFIG=$DOCKER_CONFIG docker ps -q -f name=syntho-offline-registry)" ]; then
      echo "The Docker container 'syntho-offline-registry' is running on localhost:$AVAILABLE_PORT."
      return 0
    else
      echo "The Docker container 'syntho-offline-registry' is not running."
      return 1
    fi
}

delete_registry2() {
    echo "deleting syntho-offline-registry container"
    DOCKER_CONFIG=$DOCKER_CONFIG docker rm -f syntho-offline-registry

    # give some time
    sleep 5

    # Verify if Docker container is NOT running
    if [ "$(DOCKER_CONFIG=$DOCKER_CONFIG docker ps -q -f name=syntho-offline-registry)" ]; then
      echo "The Docker container 'syntho-offline-registry' is still running on localhost:$AVAILABLE_PORT."
      return 1
    else
      echo "The Docker container 'syntho-offline-registry' is not running anymore."
      return 0
    fi
}


archive_offline_registry() {
    echo "archiving syntho-offline-registry container"
    echo "copying registry lib in the host machine"
    OFFLINE_MODE_DATASOURCE="$DEPLOYMENT_DIR/activate-offline-mode"
    mkdir -p $OFFLINE_MODE_DATASOURCE
    DOCKER_CONFIG=$DOCKER_CONFIG docker cp syntho-offline-registry:/var/lib/registry $OFFLINE_MODE_DATASOURCE/registry-backup

    echo "archiving registry lib backup in the host machine"
    tar -czf $OFFLINE_MODE_DATASOURCE/registry-lib.tar.gz -C $OFFLINE_MODE_DATASOURCE/registry-backup .

    echo "removing the backup dir again because it was archived"
    rm -rf $OFFLINE_MODE_DATASOURCE/registry-backup

    echo "stopping container"
    DOCKER_CONFIG=$DOCKER_CONFIG docker stop syntho-offline-registry

    echo "commiting container's catalogs into a new image"
    DOCKER_CONFIG=$DOCKER_CONFIG docker commit syntho-offline-registry syntho-offline-registry:latest

    echo "archiving the new syntho-offline-registry:latest image"
    DOCKER_CONFIG=$DOCKER_CONFIG docker save -o $OFFLINE_MODE_DATASOURCE/syntho-offline-registry.tar syntho-offline-registry:latest
}


prepare_final_versions() {
    # Initially store all env keys in an array
    # shellcheck disable=SC2207
    initial_keys=($(env | cut -d= -f1))

    # Apply the default values from the .images.env file
    while read -r line || [[ -n "$line" ]]; do
        export "${line?}"
    done < "${DEPLOYMENT_DIR}/.images.env"

    #If ARCH is arm, override with the values from the .images-arm.env file
    if [[ "$ARCH" == "arm" ]]; then
        while read -r line || [[ -n "$line" ]]; do
            export "${line?}"
        done < ${DEPLOYMENT_DIR}/.images-arm.env
    fi

    # Get all the keys that are newly added (difference from initial_keys)
    # shellcheck disable=SC2207
    new_keys=($(comm -3 <(printf "%s\n" "${initial_keys[@]}" | sort) <(env | cut -d= -f1 | sort)))

    # Write only these envs to the final file
    for key in "${new_keys[@]}"; do
        echo "$key=${!key}" >> ${DEPLOYMENT_DIR}/.images-merged.env
    done

    # Read environment variables from the .images-merged.env file
    while IFS= read -r line
    do
      # Extract key and value
      key="${line%%=*}"
      value="${line#*=}"

      # Check if this is the variable we're interested in
      if [ "$key" = "IMAGE_REGISTRY_SERVER" ]; then
        export "$key=$value"
      else
        # Write all other variables to the .images-final.env file
        echo "$key=$value" >> ${DEPLOYMENT_DIR}/.images-final.env
      fi

    done < ${DEPLOYMENT_DIR}/.images-merged.env
}

prepare_offline_images() {
    # Temporary files
    img_repo="${DEPLOYMENT_DIR}/.img_repo_tmp"
    img_key="${DEPLOYMENT_DIR}/.img_key_tmp"
    img_tag="${DEPLOYMENT_DIR}/.img_tag_tmp"
    img_offline="${DEPLOYMENT_DIR}/.images-offline.env"

    # Create/Empty files
    > $img_repo true
    > $img_key true
    > $img_tag true
    > $img_offline true

    # Add OFFLINE_IMAGE_REGISTRY_SERVER and IMAGE_REGISTRY_SERVER to offline file
    IMAGE_REGISTRY_SERVER=$(grep IMAGE_REGISTRY_SERVER ${DEPLOYMENT_DIR}/.images-merged.env | cut -d '=' -f2)
    echo "OFFLINE_IMAGE_REGISTRY_SERVER=$OFFLINE_REGISTRY" >> $img_offline

    # read file line by line
    while read -r line; do
        key="${line%%=*}"
        value="${line#*=}"

        # make sure we don't mistakenly handle IMAGE_REGISTRY_SERVER
        if [[ $key == *_IMG_REPO && $key != "IMAGE_REGISTRY_SERVER" ]]; then
            echo "$key" >> $img_key
            echo "$value" >> $img_repo
        elif [[ $key == *_IMG_TAG ]]; then
            echo "$value" >> $img_tag
        fi
    done < ${DEPLOYMENT_DIR}/.images-final.env

    # generate docker pull commands and write to offline env file
    while read -r key <&3 && read -r repo <&4 && read -r tag <&5; do
        # create offline version of repo and tag variables
        if [[ $repo == $IMAGE_REGISTRY_SERVER* ]]; then
            new_repo=${repo/#$IMAGE_REGISTRY_SERVER/$OFFLINE_REGISTRY}
        else
            modified_repo=$(echo ${repo} | tr '/' '-')
            new_repo="${OFFLINE_REGISTRY}/syntho-${modified_repo}"
        fi

        OFFLINE_VARIABLE=${key//_REPO/}
        echo "OFFLINE_${OFFLINE_VARIABLE}_REPO=$new_repo" >> $img_offline # Replaced _IMG_REPO with _REPO
        echo "OFFLINE_${OFFLINE_VARIABLE}_TAG=$tag" >> $img_offline       # Replaced _IMG_TAG with _TAG

    done 3< $img_key 4< $img_repo 5< $img_tag

    # Clean up temporary files
    rm -f $img_repo $img_key $img_tag
}


pull_images() {
    # Temporary files
    img_pair="${DEPLOYMENT_DIR}/.img_pair_tmp"

    # Create/Empty file
    > $img_pair true

    # Source offline image env file
    source "${DEPLOYMENT_DIR}/.images-offline.env"

    # read file line by line
    while IFS='=' read -r key value; do
        if [[ $key == *_IMG_REPO ]]; then
            base_key="${key%_IMG_REPO}"
            original_tag=$(grep "${base_key}_IMG_TAG=" ${DEPLOYMENT_DIR}/.images-final.env | cut -d '=' -f2)
            echo "$base_key $value $original_tag" >> $img_pair
        fi
    done < "${DEPLOYMENT_DIR}/.images-final.env"

    # generate docker pull, tag and push commands
    while read -r base_key repo original_tag; do
        echo "DOCKER_CONFIG=$DOCKER_CONFIG docker pull ${repo}:${original_tag}"
        DOCKER_CONFIG=$DOCKER_CONFIG docker pull ${repo}:${original_tag}

        offline_repo_var="OFFLINE_${base_key}_IMG_REPO"
        offline_tag_var="OFFLINE_${base_key}_IMG_TAG"

        offline_repo=${!offline_repo_var}
        offline_tag=${!offline_tag_var}

        echo "DOCKER_CONFIG=$DOCKER_CONFIG docker tag ${repo}:${original_tag} ${offline_repo}:${offline_tag}"
        DOCKER_CONFIG=$DOCKER_CONFIG docker tag ${repo}:${original_tag} ${offline_repo}:${offline_tag}

        echo "DOCKER_CONFIG=$DOCKER_CONFIG docker push ${offline_repo}:${offline_tag}"
        DOCKER_CONFIG=$DOCKER_CONFIG docker push ${offline_repo}:${offline_tag}

    done < "$img_pair"

    # Clean up temporary file
    rm -f $img_pair
}



with_loading "Downloading the release: $VERSION" download_release
with_loading "Extracting the release: $VERSION" extract_release
with_loading "Creating an offline image registry" create_offline_image_registry
