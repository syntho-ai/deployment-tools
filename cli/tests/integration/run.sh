#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e
# Print commands and their arguments as they are executed (optional for debugging)
set -x

if [[ $CLUSTER_NAME == "" ]]; then
    echo "CLUSTER_NAME should be provided for running the integration tests"
    exit 1
fi

if [[ $LICENSE_KEY == "" ]]; then
    echo "LICENSE_KEY should be provided for running the integration tests"
    exit 1
fi

if [[ $REGISTRY_USER == "" ]]; then
    echo "REGISTRY_USER should be provided for running the integration tests"
    exit 1
fi

if [[ $REGISTRY_PWD == "" ]]; then
    echo "REGISTRY_PWD should be provided for running the integration tests"
    exit 1
fi

if [[ $VERSION == "" ]]; then
    echo "VERSION should be provided for running the integration tests"
    exit 1
fi

# Get kubeconfig for the kind cluster and check if the command was successful
if ! KUBECONFIG=$(kind get kubeconfig --name "$CLUSTER_NAME" 2>/dev/null); then
    echo "Kind cluster with name $CLUSTER_NAME does not exist or could not be reached."
    exit 1
fi

CLUSTER_CONTAINER_NAME=${CLUSTER_NAME}-control-plane
CLUSTER_CONTAINER_ID=$(docker ps -q -f "name=${CLUSTER_CONTAINER_NAME}")
if [ -z "$CLUSTER_CONTAINER_ID" ]; then
  echo "No container found for kind cluster '${CLUSTER_NAME}'."
  exit 1
fi

CLUSTER_NETWORK=$(docker inspect "$CLUSTER_CONTAINER_NAME" | jq -r '.[0].NetworkSettings.Networks | keys[] | select(. != "bridge") | . ' | head -n 1)
if [ -z "$CLUSTER_NETWORK" ]; then
  echo "No network found for kind cluster '${CLUSTER_NAME}'."
  exit 1
fi

CLUSTER_INTERNAL_PORT=$(docker inspect "$CLUSTER_CONTAINER_NAME" | jq -r '.[0].NetworkSettings.Ports | keys[0] | split("/")[0] | gsub(" ";"")')

RUN_DIR=${0}
# shellcheck disable=SC2164
SCRIPT_DIR="$( cd "$(dirname "${RUN_DIR}")" >/dev/null 2>&1 ; pwd -P )"

prepare() {
    local SOURCE_DIR
    local DEST_DIR="$SCRIPT_DIR/temp-workspace"
    mkdir -p "$DEST_DIR"

    SOURCE_DIR="$(realpath "$SCRIPT_DIR/../../../cli")"
    rsync -av --progress --exclude 'tests' "$SOURCE_DIR/" "$DEST_DIR/cli"

    SOURCE_DIR="$(realpath "$SCRIPT_DIR/../../../helm")"
    rsync -av --progress "$SOURCE_DIR/" "$DEST_DIR/helm"

    SOURCE_DIR="$(realpath "$SCRIPT_DIR/../../../docker-compose")"
    rsync -av --progress "$SOURCE_DIR/" "$DEST_DIR/docker-compose"

    echo "$KUBECONFIG" > ./kubeconfig
}

build() {
    docker build \
        --build-arg KUBECONFIG=./kubeconfig \
        --build-arg CLUSTER_CONTAINER_NAME=$CLUSTER_CONTAINER_NAME \
        --build-arg CLUSTER_INTERNAL_PORT=$CLUSTER_INTERNAL_PORT -t integration-test-image .
}

run_k8s_tests() {
    DEPLOY_K8S_COMMAND="syntho-cli k8s deployment --license-key $LICENSE_KEY --registry-user $REGISTRY_USER --registry-pwd $REGISTRY_PWD --version $VERSION --kubeconfig /root/.kube/config --skip-configuration --dry-run"
    FIND_DEPLOYMENT_ID_COMMAND="DEPLOYMENT_ID=\$(syntho-cli k8s deployments | yq '.[0].id')"
    DESTROY_DEPLOYMENT_COMMAND="syntho-cli k8s destroy --deployment-id \$DEPLOYMENT_ID"
    docker run --network $CLUSTER_NETWORK -t integration-test-image /bin/bash -c "
      set -e;
      $DEPLOY_K8S_COMMAND || { cat /tmp/syntho/*.log; exit 1; };
      $FIND_DEPLOYMENT_ID_COMMAND;
      $DESTROY_DEPLOYMENT_COMMAND;
    "
}

run_dc_tests() {
    DEPLOY_DC_COMMAND="syntho-cli dc deployment --license-key $LICENSE_KEY --registry-user $REGISTRY_USER --registry-pwd $REGISTRY_PWD --version $VERSION --skip-configuration --dry-run"
    FIND_DEPLOYMENT_ID_COMMAND="DEPLOYMENT_ID=\$(syntho-cli dc deployments | yq '.[0].id')"
    DESTROY_DEPLOYMENT_COMMAND="syntho-cli dc destroy --deployment-id \$DEPLOYMENT_ID"
    docker run -v /var/run/docker.sock:/var/run/docker.sock -t integration-test-image /bin/bash -c "
      set -e;
      $DEPLOY_DC_COMMAND || { cat /tmp/syntho/*.log; exit 1; };
      $FIND_DEPLOYMENT_ID_COMMAND;
      $DESTROY_DEPLOYMENT_COMMAND;
    "
}

cleanup() {
    rm ./kubeconfig
    rm -rf ./temp-workspace
}

trap cleanup EXIT

prepare
build
run_k8s_tests
run_dc_tests
