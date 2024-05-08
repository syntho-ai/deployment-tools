#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only


DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
FORCE="$FORCE"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"


source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only &> /dev/null
NAMESPACE=syntho
SECRET_NAME_FOR_IMAGE_REGISTRY=syntho-cr-secret
DEPLOY_LOCAL_VOLUME_PROVISIONER="$DEPLOY_LOCAL_VOLUME_PROVISIONER"
DEPLOY_INGRESS_CONTROLLER="$DEPLOY_INGRESS_CONTROLLER"

delete_ray_cluster() {
    if [[ $FORCE == "true" ]]; then
        helm --kubeconfig $KUBECONFIG uninstall ray-cluster --namespace syntho --no-hooks --timeout 0
    else
        helm --kubeconfig $KUBECONFIG uninstall ray-cluster --namespace syntho
    fi
}

delete_synthoui() {
    if [[ $FORCE == "true" ]]; then
        helm --kubeconfig $KUBECONFIG uninstall syntho-ui --namespace syntho --no-hooks --timeout 0
    else
        helm --kubeconfig $KUBECONFIG uninstall syntho-ui --namespace syntho
    fi
}

delete_image_registry_secret() {
    if [[ $FORCE == "true" ]]; then
        kubectl --kubeconfig $KUBECONFIG --namespace syntho delete secret $SECRET_NAME_FOR_IMAGE_REGISTRY --grace-period=0 --force
    else
        kubectl --kubeconfig $KUBECONFIG --namespace syntho delete secret $SECRET_NAME_FOR_IMAGE_REGISTRY
    fi
}

delete_namespace_if_exists() {
    # Check if the namespace exists
    if kubectl --kubeconfig "$KUBECONFIG" get namespace "$NAMESPACE" &> /dev/null; then
        # Delete the namespace
        if [[ $FORCE == "true" ]]; then
            kubectl --kubeconfig "$KUBECONFIG" delete namespace "$NAMESPACE" --grace-period=0 --force
        else
            kubectl --kubeconfig "$KUBECONFIG" delete namespace "$NAMESPACE"
        fi
        echo "Namespace deleted."
    else
        echo "Namespace does not exist."
    fi
}

delete_local_path_provisioner() {
    if [[ $FORCE == "true" ]]; then
        helm --kubeconfig $KUBECONFIG uninstall syntho-local-path-storage --namespace syntho --no-hooks --timeout 0
    else
        helm --kubeconfig $KUBECONFIG uninstall syntho-local-path-storage --namespace syntho
    fi
}

delete_nginx_ingress_controller() {
    if [[ $FORCE == "true" ]]; then
        helm --kubeconfig $KUBECONFIG uninstall syntho-ingress-nginx --namespace syntho --no-hooks --timeout 0
    else
        helm --kubeconfig $KUBECONFIG uninstall syntho-ingress-nginx --namespace syntho
    fi
}



destroy() {
    delete_synthoui
    delete_ray_cluster
    delete_image_registry_secret

    if [[ "$DEPLOY_LOCAL_VOLUME_PROVISIONER" == "y" ]]; then
        delete_local_path_provisioner
    fi

    if [[ "$DEPLOY_INGRESS_CONTROLLER" == "y" ]]; then
        delete_nginx_ingress_controller
    fi

    if [[ $FORCE == "true" ]]; then
        kubectl --kubeconfig $KUBECONFIG delete pods --namespace syntho --grace-period=0 --force --all
    fi

    delete_namespace_if_exists
}

destroy_with_error_handling() {
    local errors=""


    if ! destroy >/dev/null 2>&1; then
        errors+="Failed to clean up components\n"
    fi

    write_and_exit "$errors" "destroy_with_error_handling"
}

with_loading "Cleaning things up (destroying)" destroy_with_error_handling 300
