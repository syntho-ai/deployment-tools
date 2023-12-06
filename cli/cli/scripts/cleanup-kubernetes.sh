#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only


DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"


source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only &> /dev/null
NAMESPACE=syntho
SECRET_NAME_FOR_IMAGE_REGISTRY=syntho-cr-secret
DEPLOY_LOCAL_VOLUME_PROVISIONER="$DEPLOY_LOCAL_VOLUME_PROVISIONER"
DEPLOY_INGRESS_CONTROLLER="$DEPLOY_INGRESS_CONTROLLER"

delete_ray_cluster() {
    helm --kubeconfig $KUBECONFIG uninstall ray-cluster --namespace syntho
}

delete_synthoui() {
    helm --kubeconfig $KUBECONFIG uninstall syntho-ui --namespace syntho
}

delete_image_registry_secret() {
    kubectl --kubeconfig $KUBECONFIG --namespace syntho delete secret syntho-cr-secret
}

delete_namespace_if_exists() {
    # Check if the namespace exists
    if kubectl --kubeconfig "$KUBECONFIG" get namespace "$NAMESPACE" &> /dev/null; then
        # Delete the namespace
        kubectl --kubeconfig "$KUBECONFIG" delete namespace "$NAMESPACE"
        echo "Namespace deleted."
    else
        echo "Namespace does not exist."
    fi
}

delete_local_path_provisioner() {
    helm --kubeconfig $KUBECONFIG uninstall \
        syntho-local-path-storage --namespace syntho-local-path-storage

    # Check if the namespace exists
    if kubectl --kubeconfig "$KUBECONFIG" get namespace syntho-local-path-storage &> /dev/null; then
        # Delete the namespace
        kubectl --kubeconfig "$KUBECONFIG" delete namespace syntho-local-path-storage
        echo "Namespace deleted."
    else
        echo "Namespace does not exist."
    fi
}

delete_nginx_ingress_controller() {
    helm --kubeconfig $KUBECONFIG uninstall \
        syntho-ingress-nginx --namespace syntho-ingress-nginx

    # Check if the namespace exists
    if kubectl --kubeconfig "$KUBECONFIG" get namespace syntho-ingress-nginx &> /dev/null; then
        # Delete the namespace
        kubectl --kubeconfig "$KUBECONFIG" delete namespace syntho-ingress-nginx
        echo "Namespace deleted."
    else
        echo "Namespace does not exist."
    fi
}



destroy() {
    delete_ray_cluster
    delete_synthoui
    delete_image_registry_secret
    delete_namespace_if_exists

    if [[ "$DEPLOY_LOCAL_VOLUME_PROVISIONER" == "y" ]]; then
        delete_local_path_provisioner
    fi

    if [[ "$DEPLOY_INGRESS_CONTROLLER" == "y" ]]; then
        delete_nginx_ingress_controller
    fi
}

destroy_with_error_handling() {
    local errors=""


    if ! destroy >/dev/null 2>&1; then
        errors+="Error: Failed to clean up components\n"
    fi

    echo -n "$errors"
}


# destroy
with_loading "Cleaning things up (destroying)" destroy_with_error_handling 2

# KUBECONFIG="$KUBECONFIG"
# helm --kubeconfig $KUBECONFIG uninstall ray-cluster
# helm --kubeconfig $KUBECONFIG uninstall syntho-ui
# kubectl --kubeconfig $KUBECONFIG delete namespace mynamespace --grace-period=0 --force
