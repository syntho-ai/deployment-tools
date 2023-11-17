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

# =============================== Configuration ===================================================

echo "Step 2: Configuration;"

echo -n -e "\t- Creating syntho namespace"

for _ in {1..4}; do
  echo -n "."
  sleep 1
done
echo " done."

read -p $'\t- Do you want to use an existing volume (should be RWX supported)? (N/y): ' USE_EXISTING_VOLUMES
USE_EXISTING_VOLUMES=${USE_EXISTING_VOLUMES:-N}

if [[ "$USE_EXISTING_VOLUMES" == "Y" || "$USE_EXISTING_VOLUMES" == "y" ]]; then
    while true; do
        read -p $'\t- Please provide pv-label-key that is used in PV (mandatory)?: ' PV_LABEL_KEY
        if [ -z "$PV_LABEL_KEY" ]; then
            echo -e "\t- Value is mandatory. Please provide a value."
        else
            break
        fi
    done
else
    PV_LABEL_KEY=""
fi

if [ -n "$PV_LABEL_KEY" ]; then
    STORAGE_CLASS_NAME=""
    STORAGE_CLASS_ACCESS_MODE="ReadWriteMany"
else
    read -p $'\t- Do you want to use your own storage class for provisioning volumes? (Y/n): ' USE_STORAGE_CLASS
    USE_STORAGE_CLASS=${USE_STORAGE_CLASS:-Y}
    if [[ "$USE_STORAGE_CLASS" == "Y" || "$USE_STORAGE_CLASS" == "y" ]]; then
        while true; do
            read -p $'\t- Please provide the storage class name that supports RWX that will be used in PVC (mandatory)?: ' STORAGE_CLASS_NAME
            if [ -z "$STORAGE_CLASS_NAME" ]; then
                echo -e "\t- Value is mandatory. Please provide a value."
            else
                STORAGE_CLASS_ACCESS_MODE="ReadWriteMany"
                break
            fi
        done
    else
        STORAGE_CLASS_NAME="standard"
        STORAGE_CLASS_ACCESS_MODE="ReadWriteOnce"
    fi
fi


read -p $'\t- Do you want to use your own ingress controller for reaching the Syntho\'s UI? (Y/n): ' USE_INGRESS_CONTROLLER
USE_INGRESS_CONTROLLER=${USE_INGRESS_CONTROLLER:-Y}
if [[ "$USE_INGRESS_CONTROLLER" == "Y" || "$USE_INGRESS_CONTROLLER" == "y" ]]; then
    while true; do
        read -p $'\t- Please provide the ingress controller class name that will be used in Ingress record (mandatory)?: ' INGRESS_CLASS_NAME
        if [ -z "$INGRESS_CLASS_NAME" ]; then
            echo -e "\t- Value is mandatory. Please provide a value."
        else
            break
        fi
    done
else
    INGRESS_CLASS_NAME="nginx"
fi


read -p $'\t- What is the preferred protocol for reaching the UI (HTTPS/http): ' PROTOCOL
PROTOCOL=${PROTOCOL:-https}
PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')
if [ "$PROTOCOL" == "https" ]; then
    read -p $'\t- Do you want it to be TLS secured? (Y/n): ' TLS_ENABLED
    TLS_ENABLED=${TLS_ENABLED:-y}
    if [[ "$TLS_ENABLED" == "Y" || "$TLS_ENABLED" == "y" ]]; then
        read -p $'\t- Do you want to create SSL certificate secret in the cluster yourself (secret name should be `frontend-tls` in `syntho` namespace) (N/y): ' OWN_SSL_SECRET
        OWN_SSL_SECRET=${OWN_SSL_SECRET:-n}
    else
        OWN_SSL_SECRET=n
    fi

    if [[ ( "$TLS_ENABLED" == "Y" || "$TLS_ENABLED" == "y" ) && ( "$OWN_SSL_SECRET" == "N" || "$OWN_SSL_SECRET" == "n" ) ]]; then
        while true; do
            read -p $'\t- Please provide ssl-certificate.crt: (mandatory)' SSL_CERT
            if [ -z "$SSL_CERT" ]; then
                echo -e "\t- Value is mandatory. Please provide a value."
            else
                break
            fi
        done

        while true; do
            read -p $'\t- Please provide ssl-private.key: (mandatory)' SSL_P_KEY
            if [ -z "$SSL_P_KEY" ]; then
                echo -e "\t- Value is mandatory. Please provide a value."
            else
                break
            fi
        done
    else
        SSL_CERT=
        SSL_P_KEY=
    fi

else
    TLS_ENABLED=n
    OWN_SSL_SECRET=n
    SSL_CERT=
    SSL_P_KEY=
fi

if [[ "$TLS_ENABLED" == "Y" || "$TLS_ENABLED" == "y" ]]; then
    TLS_ENABLED=true
else
    TLS_ENABLED=false
fi

if [[ "$OWN_SSL_SECRET" == "Y" || "$OWN_SSL_SECRET" == "y" ]]; then
    OWN_SSL_SECRET=true
else
    OWN_SSL_SECRET=false
fi

read -p $'\t- What is the preferred domain for reaching the UI (default: syntho.company.com): ' DOMAIN
DOMAIN=${DOMAIN:-syntho.company.com}

read -p $'\t- Which version of Syntho stack you want to deploy? (default: stable): ' SYNTHO_VERSION
SYNTHO_VERSION=${SYNTHO_VERSION:-stable}

read -p $'\t- How much CPU resource you would like to use for the ray head (eg. 32000m) (default: 1000m): ' CPU_RESOURCE_RAY_HEAD
CPU_RESOURCE_RAY_HEAD=${CPU_RESOURCE_RAY_HEAD:-1000m}

read -p $'\t- How much memory resource you would like to use for the ray head (eg. 16Gi) (default: 4Gi): ' MEMORY_RESOURCE_RAY_HEAD
MEMORY_RESOURCE_RAY_HEAD=${MEMORY_RESOURCE_RAY_HEAD:-4Gi}


echo "Step 3: Deployment;"

echo -n -e "\t- Getting the $SYNTHO_VERSION-$ARCH version of Syntho stack"

for _ in {1..4}; do
  echo -n "."
  sleep 1
done
echo " done."

echo -n -e "\t- Setting up necessary secrets (for tls and accessing image repo) into kubernetes cluster"

for _ in {1..4}; do
  echo -n "."
  sleep 1
done
echo " done."

echo -n -e "\t- Setting up an ingress controller"

for _ in {1..4}; do
  echo -n "."
  sleep 1
done
echo " done."

echo -n -e "\t- Setting up a local volume provisioner"

for _ in {1..4}; do
  echo -n "."
  sleep 1
done
echo " done."

echo -n -e "\t- Deploying Syntho stack (this might take some time)"

for _ in {1..4}; do
  echo -n "."
  sleep 2
done
echo " done."

echo "Syntho stack got deployed. Please visit: $PROTOCOL://$DOMAIN"
echo "PS: Make sure the DNS configuration is made properly on your side!"

# kubectl port-forward service/ingress-nginx-controller 32282:80 -n ingress-nginx
# curl -H "Host: syntho.company.com" http://localhost:32282
