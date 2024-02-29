#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

TRUSTED_REGISTRY="$TRUSTED_REGISTRY"
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

pull_images_into_trusted_registry() {
    sleep 1
    local errors=""

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/pull_images_into_trusted_registry.log"

    if ! prepare_final_versions >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when preparing final image versions\n"
    fi

    if ! prepare_trusted_images >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="An unexpected error occured when preparing trusted image versions\n"
    fi

    if ! pull_images >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Pulling images into the trusted registry has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "pull_images_into_trusted_registry"
}


prepare_final_versions() {
    # Initially store all env keys in an array 
    initial_keys=($(env | cut -d= -f1))

    # Apply the default values from the .images.env file
    while read -r line || [[ -n "$line" ]]; do
        export "$line"
    done < ${DEPLOYMENT_DIR}/.images.env

    #If ARCH is arm, override with the values from the .images-arm.env file
    if [[ "$ARCH" == "arm" ]]; then
        while read -r line || [[ -n "$line" ]]; do
            export "$line"
        done < ${DEPLOYMENT_DIR}/.images-arm.env
    fi

    # Get all the keys that are newly added (difference from initial_keys)
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

prepare_trusted_images() {
    # Temporary files
    img_repo="${DEPLOYMENT_DIR}/.img_repo_tmp"
    img_key="${DEPLOYMENT_DIR}/.img_key_tmp"
    img_tag="${DEPLOYMENT_DIR}/.img_tag_tmp"
    img_trusted="${DEPLOYMENT_DIR}/.images-trusted.env"

    # Create/Empty files
    > $img_repo
    > $img_key
    > $img_tag
    > $img_trusted

    # Add TRUSTED_IMAGE_REGISTRY_SERVER and IMAGE_REGISTRY_SERVER to trusted file
    IMAGE_REGISTRY_SERVER=$(grep IMAGE_REGISTRY_SERVER ${DEPLOYMENT_DIR}/.images-merged.env | cut -d '=' -f2)
    echo "TRUSTED_IMAGE_REGISTRY_SERVER=$TRUSTED_REGISTRY" >> $img_trusted

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

    # generate docker pull commands and write to trusted env file
    while read -r key <&3 && read -r repo <&4 && read -r tag <&5; do
        # create trusted version of repo and tag variables
        if [[ $repo == $IMAGE_REGISTRY_SERVER* ]]; then
            new_repo=${repo/#$IMAGE_REGISTRY_SERVER/$TRUSTED_REGISTRY}
        else
            modified_repo=$(echo ${repo} | tr '/' '-')
            new_repo="${TRUSTED_REGISTRY}/syntho-${modified_repo}"
        fi

        TRUSTED_VARIABLE=${key//_REPO/}
        echo "TRUSTED_${TRUSTED_VARIABLE}_REPO=$new_repo" >> $img_trusted  # Replaced _IMG_REPO with _REPO
        echo "TRUSTED_${TRUSTED_VARIABLE}_TAG=$tag" >> $img_trusted         # Replaced _IMG_TAG with _TAG

    done 3< $img_key 4< $img_repo 5< $img_tag

    # Clean up temporary files
    rm -f $img_repo $img_key $img_tag
}


pull_images() {
    # Temporary files
    img_pair="${DEPLOYMENT_DIR}/.img_pair_tmp"
    img_trusted="${DEPLOYMENT_DIR}/.images-trusted.env"

    # Create/Empty file
    > $img_pair

    # Source trusted image env file
    source $img_trusted

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

        trusted_repo_var="TRUSTED_${base_key}_IMG_REPO"
        trusted_tag_var="TRUSTED_${base_key}_IMG_TAG"

        trusted_repo=${!trusted_repo_var}
        trusted_tag=${!trusted_tag_var}

        echo "DOCKER_CONFIG=$DOCKER_CONFIG docker tag ${repo}:${original_tag} ${trusted_repo}:${trusted_tag}"
        DOCKER_CONFIG=$DOCKER_CONFIG docker tag ${repo}:${original_tag} ${trusted_repo}:${trusted_tag}
        
        echo "DOCKER_CONFIG=$DOCKER_CONFIG docker push ${trusted_repo}:${trusted_tag}"
        DOCKER_CONFIG=$DOCKER_CONFIG docker push ${trusted_repo}:${trusted_tag}

    done < "$img_pair"

    # Clean up temporary file
    rm -f $img_pair
}



with_loading "Downloading the release: $VERSION" download_release
with_loading "Extracting the release: $VERSION" extract_release
with_loading "Pulling images into the trusted registry ($TRUSTED_REGISTRY)" pull_images_into_trusted_registry
