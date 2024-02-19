#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"
GIVEN_ARCH="${ARCH}64"


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

    write_and_exit "$errors" "network_check"
}

developer_tools_check() {
    sleep 2
    local errors=""

    # Check if curl or wget exists
    if ! command_exists "curl" && ! command_exists "wget"; then
        errors+="Missing command line tool - curl or wget\n"
    fi

    # Check if kubectl exists
    if ! command_exists "kubectl"; then
        errors+="Missing command line tool - kubectl\n"
    fi

    # Check if helm exists
    if ! command_exists "helm"; then
        errors+="Missing command line tool - helm\n"
    fi

    # Check if tar exists
    if ! command_exists "tar"; then
        errors+="Missing command line tool - tar\n"
    fi

    # Check if awk exists
    if ! command_exists "awk"; then
        errors+="Missing command line tool - awk\n"
    fi

    write_and_exit "$errors" "developer_tools_check"
}

kubernetes_cluster_check() {
    sleep 2
    local errors=""

    # Check if KUBECONFIG is unset
    if [ -z "${KUBECONFIG+x}" ]; then
        errors+="KUBECONFIG is unset.\n"
    fi

    # Check if KUBECONFIG is set to an empty string
    if [ -z "$KUBECONFIG" ]; then
        errors+="KUBECONFIG is set to an empty string.\n"
    fi

    # Check if KUBECONFIG points to a valid Kubernetes cluster
    if ! kubectl --kubeconfig="$KUBECONFIG" config current-context &> /dev/null; then
        errors+="KUBECONFIG does not point to a valid Kubernetes cluster.\n"
    fi

    SERVER_ARCH=$(kubectl --kubeconfig="$KUBECONFIG" get nodes -o json | jq -r '.items[0].status.nodeInfo.architecture')
    if [[ $GIVEN_ARCH != $SERVER_ARCH ]]; then
        errors+="given --arch parameter isn't consistent with the kubernetes cluster's architecture($SERVER_ARCH). Supported --arch parameters are amd or arm and eventually both will be converted to amd64 or arm64. No other architectures are supported by the cli.\n"
    fi

    write_and_exit "$errors" "kubernetes_cluster_check"
}


dump_k8s_server_info() {
    NODES=$(kubectl --kubeconfig="$KUBECONFIG" get nodes --show-labels)

    NUM_OF_NODES=$(echo "${NODES}" | grep -v NAME | wc -l | tr -d ' ')
    IS_MANAGED="false"
    if echo "${NODES}" | grep -q -e 'gke\|aws\|aks'; then
      IS_MANAGED="true"
    fi

    cat << EOF > "$DEPLOYMENT_DIR/.k8s-cluster-info.env"
NUM_OF_NODES=$NUM_OF_NODES
IS_MANAGED=$IS_MANAGED
EOF
}

check_if_configurations_can_be_skipped() {
    sleep 2
    local errors=""

    source $DEPLOYMENT_DIR/.k8s-cluster-info.env --source-only
    NUM_OF_NODES=$NUM_OF_NODES
    IS_MANAGED="$IS_MANAGED"

    if [[ $SKIP_CONFIGURATION == "true" ]]; then
        if [[ $IS_MANAGED == "true" ]]; then
            errors+="Configuration can't be skipped as the Kubernetes cluster is a managed cluster and some default configuration is not compatible with it.\n"
        elif [[ $NUM_OF_NODES -gt 1 ]]; then
            errors+="Configuration can't be skipped as the Kubernetes cluster is a multi-node cluster and some default configuration is not compatible with it.\n"
        fi
    fi

    write_and_exit "$errors" "check_if_configurations_can_be_skipped"
}

with_loading "Checking network connectivity" network_check
with_loading "Checking developer tools" developer_tools_check
with_loading "Checking if the given KUBECONFIG points to a valid k8s cluster" kubernetes_cluster_check

dump_k8s_server_info

if [[ $SKIP_CONFIGURATION == "true" ]]; then
    with_loading "Checking if the cluster is compatible with the default configuration settings" check_if_configurations_can_be_skipped
fi
