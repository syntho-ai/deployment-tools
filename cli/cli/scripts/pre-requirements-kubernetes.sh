#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only


developer_tools_check() {
    sleep 2
    local errors=""

    # Check if curl or wget exists
    if ! command_exists "curl" && ! command_exists "wget"; then
        errors+="Error: Missing command line tool - curl or wget\n"
    fi

    # Check if kubectl exists
    if ! command_exists "kubectl"; then
        errors+="Error: Missing command line tool - kubectl\n"
    fi

    # Check if helm exists
    if ! command_exists "helm"; then
        errors+="Error: Missing command line tool - helm\n"
    fi

    # Check if tar exists
    if ! command_exists "tar"; then
        errors+="Error: Missing command line tool - tar\n"
    fi

    echo -n "$errors"
}

kubernetes_cluster_check() {
    sleep 2
    local errors=""

    # Check if KUBECONFIG is set
    if [ -z "$KUBECONFIG" ]; then
        errors+="Error: KUBECONFIG is not set.\n"
    fi

    # Check if KUBECONFIG points to a valid Kubernetes cluster
    if ! kubectl --kubeconfig="$KUBECONFIG" config current-context &> /dev/null; then
        errors+="Error: KUBECONFIG does not point to a valid Kubernetes cluster.\n"
    fi

    echo -n "$errors"
}


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"


with_loading "Checking developer tools" developer_tools_check
with_loading "Checking if the given KUBECONFIG points to a valid k8s cluster" kubernetes_cluster_check
