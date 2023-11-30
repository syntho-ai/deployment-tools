#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

LICENSE_KEY="$LICENSE_KEY"
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"


while true; do
    read -p $'\t- Do you want to use an existing volume (should be RWX supported)? (N/y): ' USE_EXISTING_VOLUMES
    USE_EXISTING_VOLUMES=${USE_EXISTING_VOLUMES:-N}

    case "$USE_EXISTING_VOLUMES" in
        [nN])
            break
            ;;
        [yY])
            break
            ;;
        *)
            echo "Invalid input. Please enter 'n', 'N', 'y', or 'Y'."
            ;;
    esac
done

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

DEPLOY_LOCAL_VOLUME_PROVISIONER=n
if [ -n "$PV_LABEL_KEY" ]; then
    STORAGE_CLASS_NAME=""
    STORAGE_CLASS_ACCESS_MODE="ReadWriteMany"
else
    while true; do
        read -p $'\t- Do you want to use your own storage class for provisioning volumes (In case we create one, only a single-node k8s cluster is supported)? (Y/n): ' USE_STORAGE_CLASS
        USE_STORAGE_CLASS=${USE_STORAGE_CLASS:-Y}

        case "$USE_STORAGE_CLASS" in
            [yY])
                break
                ;;
            [nN])
                break
                ;;
            *)
                echo "Invalid input. Please enter 'y', 'Y', 'n', or 'N'."
                ;;
        esac
    done
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
        DEPLOY_LOCAL_VOLUME_PROVISIONER=y
        STORAGE_CLASS_NAME="local-path"
        STORAGE_CLASS_ACCESS_MODE="ReadWriteOnce"
    fi
fi


while true; do
    read -p $'\t- Do you want to use your own ingress controller for reaching the Syntho\'s UI? (Y/n): ' USE_INGRESS_CONTROLLER
    USE_INGRESS_CONTROLLER=${USE_INGRESS_CONTROLLER:-Y}

    case "$USE_INGRESS_CONTROLLER" in
        [yY])
            break
            ;;
        [nN])
            break
            ;;
        *)
            echo "Invalid input. Please enter 'y', 'Y', 'n', or 'N'."
            ;;
    esac
done
DEPLOY_INGRESS_CONTROLLER=n
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
    DEPLOY_INGRESS_CONTROLLER=y
    INGRESS_CLASS_NAME="nginx"
fi


while true; do
    read -p $'\t- What is the preferred protocol for reaching the UI (HTTPS/http): ' PROTOCOL
    PROTOCOL=${PROTOCOL:-https}

    case "$PROTOCOL" in
        [Hh][Tt][Tt][Pp])
            break
            ;;
        [Hh][Tt][Tt][Pp][Ss])
            break
            ;;
        *)
            echo "Invalid input. Please enter 'http' or 'https'."
            ;;
    esac
done
PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')
CREATE_SECRET_FOR_SSL=n
if [ "$PROTOCOL" == "https" ]; then
    while true; do
        read -p $'\t- Do you want it to be TLS secured? (Y/n): ' TLS_ENABLED
        TLS_ENABLED=${TLS_ENABLED:-y}

        case "$TLS_ENABLED" in
            [yY])
                break
                ;;
            [nN])
                break
                ;;
            *)
                echo "Invalid input. Please enter 'y', 'Y', 'n', or 'N'."
                ;;
        esac
    done
    if [[ "$TLS_ENABLED" == "Y" || "$TLS_ENABLED" == "y" ]]; then
        while true; do
            read -p $'\t- Do you want to create SSL certificate secret in the cluster yourself (secret name should be `frontend-tls` in `syntho` namespace) (N/y): ' OWN_SSL_SECRET
            OWN_SSL_SECRET=${OWN_SSL_SECRET:-n}

            case "$OWN_SSL_SECRET" in
                [yY])
                    break
                    ;;
                [nN])
                    break
                    ;;
                *)
                    echo "Invalid input. Please enter 'y', 'Y', 'n', or 'N'."
                    ;;
            esac
        done
    else
        OWN_SSL_SECRET=n
    fi

    if [[ ( "$TLS_ENABLED" == "Y" || "$TLS_ENABLED" == "y" ) && ( "$OWN_SSL_SECRET" == "N" || "$OWN_SSL_SECRET" == "n" ) ]]; then
        CREATE_SECRET_FOR_SSL=y
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

cat << EOF > "$DEPLOYMENT_DIR/.pre.deployment.ops.env"
DEPLOY_LOCAL_VOLUME_PROVISIONER=$DEPLOY_LOCAL_VOLUME_PROVISIONER
DEPLOY_INGRESS_CONTROLLER=$DEPLOY_INGRESS_CONTROLLER
CREATE_SECRET_FOR_SSL=$CREATE_SECRET_FOR_SSL
SSL_CERT="$SSL_CERT"
SSL_P_KEY="$SSL_P_KEY"
REGISTRY_USER=$REGISTRY_USER
REGISTRY_PWD=$REGISTRY_PWD
EOF
