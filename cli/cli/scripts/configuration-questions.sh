#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only


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

read -p $'\t- How much CPU resource you would like to use for the ray head (eg. 32000m) (default: 1000m): ' CPU_RESOURCE_RAY_HEAD
CPU_RESOURCE_RAY_HEAD=${CPU_RESOURCE_RAY_HEAD:-1000m}

read -p $'\t- How much memory resource you would like to use for the ray head (eg. 16G) (default: 4G): ' MEMORY_RESOURCE_RAY_HEAD
MEMORY_RESOURCE_RAY_HEAD=${MEMORY_RESOURCE_RAY_HEAD:-4G}



cat << EOF > "$DEPLOYMENT_DIR/.config.env"
LICENSE_KEY=$LICENSE_KEY
STORAGE_CLASS_NAME=$STORAGE_CLASS_NAME
STORAGE_CLASS_ACCESS_MODE=$STORAGE_CLASS_ACCESS_MODE
PV_LABEL_KEY=$PV_LABEL_KEY
TLS_ENABLED=$TLS_ENABLED
DOMAIN=$DOMAIN
PROTOCOL=$PROTOCOL
INGRESS_CONTROLLER=$INGRESS_CLASS_NAME
EOF

cat << EOF > "$DEPLOYMENT_DIR/.resources.env"
RAY_HEAD_CPU_REQUESTS=$(( ${CPU_RESOURCE_RAY_HEAD%"m"} / 2 ))m
RAY_HEAD_CPU_LIMIT=$CPU_RESOURCE_RAY_HEAD
RAY_HEAD_MEMORY_REQUESTS=$(( ${MEMORY_RESOURCE_RAY_HEAD%"G"} / 2 ))G
RAY_HEAD_MEMORY_LIMIT=$MEMORY_RESOURCE_RAY_HEAD
EOF
