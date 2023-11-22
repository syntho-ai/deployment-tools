#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

LICENSE_KEY="$LICENSE_KEY"
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"
ARCH="$ARCH"
KUBECONFIG="$KUBECONFIG"
VERSION="$VERSION"


source $DEPLOYMENT_DIR/.config.env --source-only

LICENSE_KEY="$LICENSE_KEY"
STORAGE_CLASS_NAME="$STORAGE_CLASS_NAME"
STORAGE_CLASS_ACCESS_MODE="$STORAGE_CLASS_ACCESS_MODE"
PV_LABEL_KEY="$PV_LABEL_KEY"
TLS_ENABLED="$TLS_ENABLED"
DOMAIN="$DOMAIN"
PROTOCOL="$PROTOCOL"
INGRESS_CONTROLLER="$INGRESS_CONTROLLER"


source $DEPLOYMENT_DIR/.resources.env --source-only

RAY_HEAD_CPU_REQUESTS="$RAY_HEAD_CPU_REQUESTS"
RAY_HEAD_CPU_LIMIT="$RAY_HEAD_CPU_LIMIT"
RAY_HEAD_MEMORY_REQUESTS="$RAY_HEAD_MEMORY_REQUESTS"
RAY_HEAD_MEMORY_LIMIT="$RAY_HEAD_MEMORY_LIMIT"


source $DEPLOYMENT_DIR/.images.env --source-only
if [[ "$ARCH" == "arm" ]]; then
    source "$DEPLOYMENT_DIR/.images-arm.env" --source-only
fi

RAY_OPERATOR_IMG_REPO="$RAY_OPERATOR_IMG_REPO"
RAY_OPEARATOR_IMG_TAG="$RAY_OPEARATOR_IMG_TAG"
RAY_IMAGE_IMG_REPO="$RAY_IMAGE_IMG_REPO"
RAY_IMAGE_IMG_TAG="$RAY_IMAGE_IMG_TAG"
SYNTHO_UI_CORE_IMG_REPO="$SYNTHO_UI_CORE_IMG_REPO"
SYNTHO_UI_CORE_IMG_VER="$SYNTHO_UI_CORE_IMG_VER"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_VER="$SYNTHO_UI_BACKEND_IMG_VER"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_VER="$SYNTHO_UI_FRONTEND_IMG_VER"



source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
IMAGE_REGISTRY_SERVER="$IMAGE_REGISTRY_SERVER"
NAMESPACE=syntho
SECRET_NAME_FOR_IMAGE_REGISTRY=syntho-cr-secret
DEPLOY_LOCAL_VOLUME_PROVISIONER="$DEPLOY_LOCAL_VOLUME_PROVISIONER"

create_namespace_if_not_exists() {
    # Check if the namespace exists
    if kubectl --kubeconfig $KUBECONFIG get namespace "$NAMESPACE" &> /dev/null; then
        echo "Namespace already exists."
    else
        # Create the namespace
        kubectl --kubeconfig $KUBECONFIG create namespace "$NAMESPACE"
        echo "Namespace created."
    fi
}

create_secret() {
    kubectl --kubeconfig $KUBECONFIG --namespace $NAMESPACE create secret docker-registry \
        $SECRET_NAME_FOR_IMAGE_REGISTRY --docker-server=$IMAGE_REGISTRY_SERVER \
        --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_PWD
}

create_namespace() {
    sleep 1
    local errors=""


    if ! create_namespace_if_not_exists >/dev/null 2>&1; then
        errors+="Error: Failed to create namespace\n"
    fi

    echo -n "$errors"
}

create_secret_for_registry_access() {
    local errors=""


    if ! create_secret >/dev/null 2>&1; then
        errors+="Error: Failed to create secret for image registry access\n"
    fi

    echo -n "$errors"
}

local_volume_provisioner() {
    kubectl --kubeconfig $KUBECONFIG apply -f \
        https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
}

install_local_volume_provisioner() {
    local errors=""


    if ! local_volume_provisioner >/dev/null 2>&1; then
        errors+="Error: Failed to install local volume provisioner\n"
    fi

    echo -n "$errors"
}


with_loading "Creating namespace" create_namespace
with_loading "Creating a kubernetes secret for image registry access" create_secret_for_registry_access

if [[ "$DEPLOY_LOCAL_VOLUME_PROVISIONER" == "y" ]]; then
    with_loading "Installing a local volume provisioner" install_local_volume_provisioner
fi
