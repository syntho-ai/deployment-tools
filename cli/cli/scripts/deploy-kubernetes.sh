#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

LICENSE_KEY="$LICENSE_KEY"
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"
KUBECONFIG="$KUBECONFIG"
ARCH="$ARCH"

source $DEPLOYMENT_DIR/.config.env --source-only
source $DEPLOYMENT_DIR/.resources.env --source-only

# =============================== Deployment ===================================================

# https://github.com/syntho-ai/syntho-charts/archive/refs/tags/{VERSION}.tar.gz


echo "Step 5: Deployment;"

echo -n -e "\t- Deploying Ray Cluster (this might take some time)"

for _ in {1..4}; do
  echo -n "."
  sleep 2
done
echo " done."

echo -n -e "\t- Deploying Syntho Stack (this might take some time)"

for _ in {1..4}; do
  echo -n "."
  sleep 2
done
echo " done."

echo "Syntho stack got deployed. Please visit: $PROTOCOL://$DOMAIN"
echo "PS: Make sure the DNS configuration is made properly on your side!"

# kubectl port-forward service/ingress-nginx-controller 32282:80 -n ingress-nginx
# curl -H "Host: syntho.company.com" http://localhost:32282
