#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

KUBECONFIG="$KUBECONFIG"
NAMESPACE=syntho

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
