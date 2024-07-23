#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"

source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"

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
    replace_versions_in_values_yaml
    helm_upgrade
}

replace_versions_in_values_yaml() {
    local RAY_DIR="${NEW_RELEASE_DIR}/helm/ray"
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
    local RAY_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/ray"
    local RAY_VALUES_YAML="${RAY_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade ray-cluster $RAY_CHARTS_DIR --values $RAY_VALUES_YAML --namespace syntho --wait --timeout 10m

    local SYNTHO_UI_CHARTS_DIR="${NEW_RELEASE_DIR}/helm/syntho-ui"
    local SYNTHO_UI_VALUES_YAML="${SYNTHO_UI_CHARTS_DIR}/values-generated.yaml"
    helm --kubeconfig $KUBECONFIG upgrade syntho-ui $SYNTHO_UI_CHARTS_DIR --values $SYNTHO_UI_VALUES_YAML --namespace syntho --wait --timeout 10m
}

do_rollout_docker_compose() {
    echo "TBI"
}

rollout_failure_callback() {
    with_loading "Deployment rollout to new release has been timedout." do_nothing "" "" 2
    with_loading "However, please check pods in syntho namespace, perhaps the deployment is still being rolled out." do_nothing "" "" 2
    with_loading "Contact support@syntho.ai in case the issue persists." do_nothing "" "" 2
}


with_loading "Fetching desired version if it was not previously rolled out: $NEW_VERSION" check_new_version_or_fetch
with_loading "Rolling out release from $CURRENT_VERSION to $NEW_VERSION" rollout_release 1800 rollout_failure_callback
