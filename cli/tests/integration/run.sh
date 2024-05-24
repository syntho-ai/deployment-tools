#!/bin/bash


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

if [[ $REGISTRY_PWD == "" ]]; then
    echo "REGISTRY_PWD should be provided for running the integration tests"
    exit 1
fi

if [[ $VERSION == "" ]]; then
    echo "VERSION should be provided for running the integration tests"
    exit 1
fi

RUN_DIR=${0}
# shellcheck disable=SC2164
SCRIPT_DIR="$( cd "$(dirname "${RUN_DIR}")" >/dev/null 2>&1 ; pwd -P )"

prepare() {
    mkdir -p "$SCRIPT_DIR/temp-workspace"
    cp -r "$SCRIPT_DIR/../../../cli" "./temp-workspace/."
    cp -r "$SCRIPT_DIR/../../../helm" "./temp-workspace/."
    cp -r "$SCRIPT_DIR/../../../docker-compose" "./temp-workspace/."

    # Get kubeconfig for the kind cluster and check if the command was successful
    if ! KUBECONFIG=$(kind get kubeconfig --name "$CLUSTER_NAME" 2>/dev/null); then
        echo "Kind cluster with name $CLUSTER_NAME does not exist or could not be reached."
        exit 1
    fi
    echo "$KUBECONFIG" > ./kubeconfig
}

build() {
    docker build --build-arg KUBECONFIG=./kubeconfig -t integration-test-image .
}

run_k8s_tests() {
    DEPLOY_K8S_COMMAND="syntho-cli k8s deployment --license-key $LICENSE_KEY --registry-user $REGISTRY_USER --registry-pwd $REGISTRY_PWD --version $VERSION --kubeconfig /root/.kube/config --skip-configuration --dry-run"
    FIND_DEPLOYMENT_ID_COMMAND="DEPLOYMENT_ID=\$(syntho-cli k8s deployments | yq '.[0].id')"
    DESTROY_DEPLOYMENT_COMMAND="syntho-cli k8s destroy --deployment-id \$DEPLOYMENT_ID"
    docker run -t integration-test-image /bin/bash -c "$DEPLOY_K8S_COMMAND && $FIND_DEPLOYMENT_ID_COMMAND && $DESTROY_DEPLOYMENT_COMMAND"
}

run_dc_tests() {
    DEPLOY_DC_COMMAND="syntho-cli dc deployment --license-key $LICENSE_KEY --registry-user $REGISTRY_USER --registry-pwd $REGISTRY_PWD --version $VERSION --skip-configuration --dry-run"
    FIND_DEPLOYMENT_ID_COMMAND="DEPLOYMENT_ID=\$(syntho-cli dc deployments | yq '.[0].id')"
    DESTROY_DEPLOYMENT_COMMAND="syntho-cli dc destroy --deployment-id \$DEPLOYMENT_ID"
    docker run -v /var/run/docker.sock:/var/run/docker.sock -t integration-test-image /bin/bash -c "$DEPLOY_DC_COMMAND && $FIND_DEPLOYMENT_ID_COMMAND && $DESTROY_DEPLOYMENT_COMMAND"
}

cleanup() {
    rm ./kubeconfig
    rm -rf ./temp-workspace
}


prepare
build
run_k8s_tests
run_dc_tests
cleanup
