#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"


source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
NAMESPACE=syntho
SECRET_NAME_FOR_IMAGE_REGISTRY=syntho-cr-secret
DEPLOY_LOCAL_VOLUME_PROVISIONER="$DEPLOY_LOCAL_VOLUME_PROVISIONER"

echo "cleanup is ran with kubeconfig: $KUBECONFIG"
# KUBECONFIG="$KUBECONFIG"
# helm --kubeconfig $KUBECONFIG uninstall ray-cluster
# helm --kubeconfig $KUBECONFIG uninstall syntho-ui
delete_image_registry_secret() {
    kubectl --kubeconfig $KUBECONFIG --namespace syntho delete secret syntho-cr-secret
}
delete_image_registry_secret

# kubectl --kubeconfig $KUBECONFIG delete namespace mynamespace --grace-period=0 --force

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
delete_namespace_if_exists

delete_local_path_provisioner() {
    helm --kubeconfig $KUBECONFIG uninstall \
        syntho-local-path-storage --namespace syntho-local-path-storage
}


if [[ "$DEPLOY_LOCAL_VOLUME_PROVISIONER" == "y" ]]; then
    delete_local_path_provisioner
fi
