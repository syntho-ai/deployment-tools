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
STORAGE_ACCESS_MODE="$STORAGE_ACCESS_MODE"
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
RAY_OPERATOR_IMG_TAG="$RAY_OPERATOR_IMG_TAG"
RAY_IMAGE_IMG_REPO="$RAY_IMAGE_IMG_REPO"
RAY_IMAGE_IMG_TAG="$RAY_IMAGE_IMG_TAG"
SYNTHO_UI_CORE_IMG_REPO="$SYNTHO_UI_CORE_IMG_REPO"
SYNTHO_UI_CORE_IMG_TAG="$SYNTHO_UI_CORE_IMG_TAG"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_TAG="$SYNTHO_UI_BACKEND_IMG_TAG"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_TAG="$SYNTHO_UI_FRONTEND_IMG_TAG"



source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
IMAGE_REGISTRY_SERVER="$IMAGE_REGISTRY_SERVER"
NAMESPACE=syntho
SECRET_NAME_FOR_IMAGE_REGISTRY=syntho-cr-secret
DEPLOY_LOCAL_VOLUME_PROVISIONER="$DEPLOY_LOCAL_VOLUME_PROVISIONER"
DEPLOY_INGRESS_CONTROLLER="$DEPLOY_INGRESS_CONTROLLER"
CREATE_SECRET_FOR_SSL=$CREATE_SECRET_FOR_SSL
SSL_CERT="$SSL_CERT"
SSL_P_KEY="$SSL_P_KEY"


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
        errors+="Failed to create namespace\n"
    fi

    write_and_exit "$errors" "create_namespace"
}

create_secret_for_registry_access() {
    local errors=""


    if ! create_secret >/dev/null 2>&1; then
        errors+="Failed to create secret for image registry access\n"
    fi

    write_and_exit "$errors" "create_secret_for_registry_access"
}

local_volume_provisioner() {
    local VERSION=0.0.24
    local V_VERSION="v${VERSION}"
    local RELEASE_URL=https://github.com/rancher/local-path-provisioner/archive/refs/tags/${V_VERSION}.tar.gz
    local TARBALL_DESTINATION=${DEPLOYMENT_DIR}/local-path-provisioner-${V_VERSION}.tar.gz
    local EXTRACT_LOCATION=${DEPLOYMENT_DIR}
    local NAMESPACE=syntho

    if ! command_exists "curl"; then
        curl -LJ "${RELEASE_URL}" -o "${TARBALL_DESTINATION}"
    else
        wget "${RELEASE_URL}" -O "${TARBALL_DESTINATION}"
    fi

    tar -xzvf "${TARBALL_DESTINATION}" -C "${EXTRACT_LOCATION}"

    helm --kubeconfig $KUBECONFIG install syntho-local-path-storage \
        --namespace syntho --create-namespace \
        ${DEPLOYMENT_DIR}/local-path-provisioner-${VERSION}/deploy/chart/local-path-provisioner/
}


install_local_volume_provisioner() {
    local errors=""


    if ! local_volume_provisioner >/dev/null 2>&1; then
        errors+="Failed to install local volume provisioner\n"
    fi

    write_and_exit "$errors" "install_local_volume_provisioner"
}

nginx_ingress_controller() {
    helm --kubeconfig $KUBECONFIG upgrade --install syntho-ingress-nginx ingress-nginx \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace syntho --create-namespace
}

install_nginx_ingress_controller() {
    local errors=""


    if ! nginx_ingress_controller >/dev/null 2>&1; then
        errors+="Failed to install nginx ingress controller\n"
    fi

    write_and_exit "$errors" "install_nginx_ingress_controller"
}

ssl_secret() {
    SSL_P_KEY=$(echo $SSL_P_KEY | base64)
    SSL_CERT=$(echo $SSL_CERT | base64)

    kubectl --kubeconfig $KUBECONFIG apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: frontend-tls
      namespace: syntho
    type: kubernetes.io/tls
    data:
      tls.key: $SSL_P_KEY
      tls.crt: $SSL_CERT
EOF
}

install_ssl_secret() {
    local errors=""


    if ! ssl_secret >/dev/null 2>&1; then
        errors+="Failed to install secret for ssl cert\n"
    fi

    write_and_exit "$errors" "install_ssl_secret"
}


with_loading "Creating namespace" create_namespace
with_loading "Creating a kubernetes secret for image registry access" create_secret_for_registry_access

if [[ "$DEPLOY_LOCAL_VOLUME_PROVISIONER" == "y" ]]; then
    with_loading "Setting up a local volume provisioner" install_local_volume_provisioner
fi

if [[ "$DEPLOY_INGRESS_CONTROLLER" == "y" ]]; then
    with_loading "Setting up nginx ingress controller" install_nginx_ingress_controller
fi

if [[ "$CREATE_SECRET_FOR_SSL" == "y" ]]; then
    with_loading "Setting up a secret for ssl cert" install_ssl_secret
fi
