#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"

echo "$(kubectl --kubeconfig="$KUBECONFIG" config current-context | xargs)"
