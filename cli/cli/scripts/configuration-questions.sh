#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"

LICENSE_KEY="$LICENSE_KEY"
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"

source $DEPLOYMENT_DIR/.k8s-cluster-info.env --source-only
NUM_OF_NODES=$NUM_OF_NODES
IS_MANAGED="$IS_MANAGED"

STORAGE_CLASS_CREATION_QUESTION_CAN_BE_ASKED="true"
if [[ $NUM_OF_NODES -gt 1 ]] || [[ $IS_MANAGED == "true" ]]; then
    while true; do
        read -p $'\t- Target cluster needs either a storage class installed, and this toolkit will use it
        to provision a volume. Or, a label value that is associated with an existing volume will need to be
        provided. Later necessary configuration questions will be asked. I acknowledge it. (Y/n): ' ACKNOWLEDGE
        ACKNOWLEDGE=${ACKNOWLEDGE:-Y}

        case "$ACKNOWLEDGE" in
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


    if [[ "$ACKNOWLEDGE" == "N" || "$ACKNOWLEDGE" == "n" ]]; then
        exit 1
    else
        echo "can't be asked"
        STORAGE_CLASS_CREATION_QUESTION_CAN_BE_ASKED="false"
    fi
fi


if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- Do you want to use an existing volume for Syntho resources? (N/y): ' USE_EXISTING_VOLUMES
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
else
    USE_EXISTING_VOLUMES=n
fi

if [[ "$USE_EXISTING_VOLUMES" == "Y" || "$USE_EXISTING_VOLUMES" == "y" ]]; then
    while true; do
        read -p $'\t- Please provide `pv-label-key` label value that will later be used as selector to bind volumes properly to Syntho resources (mandatory)?: ' PV_LABEL_KEY
        if [ -z "$PV_LABEL_KEY" ]; then
            echo -e "\t- Value is mandatory. Please provide a value."
        else
            STORAGE_CLASS_NAME=$(kubectl --kubeconfig="$KUBECONFIG" get pv -l pv-label-key=$PV_LABEL_KEY -o jsonpath="{.items[*].spec.storageClassName}")
            if [[ -n $STORAGE_CLASS_NAME ]]; then
                break
            else
                echo -e "\t- There is no such a volume found with the given label value. Please provide a correct value."
            fi
        fi
    done
else
    PV_LABEL_KEY=""
fi

DEPLOY_LOCAL_VOLUME_PROVISIONER=n
if [ -n "$PV_LABEL_KEY" ]; then
    if [[ $NUM_OF_NODES -eq 1 ]]; then
        STORAGE_ACCESS_MODE="ReadWriteOnce"
    else
        # TODO revisit here when ray cluster becomes multi node
        # STORAGE_ACCESS_MODE="ReadWriteMany"
        STORAGE_ACCESS_MODE="ReadWriteOnce"
    fi
else
    if [[ "$SKIP_CONFIGURATION" == "false" ]] && [[ "$STORAGE_CLASS_CREATION_QUESTION_CAN_BE_ASKED" == "true" ]]; then
        while true; do
            read -p $'\t- Do you want to use your own storage class for provisioning volumes? (Y/n): ' USE_STORAGE_CLASS
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
    else
        USE_STORAGE_CLASS=n
        if [[ "$STORAGE_CLASS_CREATION_QUESTION_CAN_BE_ASKED" == "false" ]]; then
            USE_STORAGE_CLASS=y
        fi
    fi

    if [[ "$USE_STORAGE_CLASS" == "Y" || "$USE_STORAGE_CLASS" == "y" ]]; then
        while true; do
            # read -p $'\t- Please provide the storage class name that supports RWX that will be used in PVC (mandatory)?: ' STORAGE_CLASS_NAME
            read -p $'\t- Please provide a storage class name (Later volumes will be created for Syntho resources) (mandatory)?: ' STORAGE_CLASS_NAME
            if [ -z "$STORAGE_CLASS_NAME" ]; then
                echo -e "\t- Value is mandatory. Please provide a value."
            else
                if kubectl --kubeconfig="$KUBECONFIG" get storageclass $STORAGE_CLASS_NAME > /dev/null 2>&1; then
                    if [[ $NUM_OF_NODES -eq 1 ]]; then
                        STORAGE_ACCESS_MODE="ReadWriteOnce"
                    else
                        # TODO revisit here when ray cluster becomes multi node
                        # STORAGE_ACCESS_MODE="ReadWriteMany"
                        STORAGE_ACCESS_MODE="ReadWriteOnce"
                    fi
                    break
                else
                    echo -e "\t- There is no such a storage class found with the given name. Please provide a correct value."
                fi
            fi
        done
    else
        DEPLOY_LOCAL_VOLUME_PROVISIONER=y
        STORAGE_CLASS_NAME="local-path"
        STORAGE_ACCESS_MODE="ReadWriteOnce"
    fi
fi


if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
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
else
    USE_INGRESS_CONTROLLER=n
fi

DEPLOY_INGRESS_CONTROLLER=n
if [[ "$USE_INGRESS_CONTROLLER" == "Y" || "$USE_INGRESS_CONTROLLER" == "y" ]]; then
    while true; do
        read -p $'\t- Please provide the ingress controller class name that will be used in Ingress record (mandatory)?: ' INGRESS_CLASS_NAME
        if [ -z "$INGRESS_CLASS_NAME" ]; then
            echo -e "\t- Value is mandatory. Please provide a value."
        else
            if kubectl --kubeconfig="$KUBECONFIG" get ingressclass $INGRESS_CLASS_NAME > /dev/null 2>&1; then
                break
            else
                echo -e "\t- There is no such an ingress class found with the given name. Please provide a correct value."
            fi
        fi
    done
else
    DEPLOY_INGRESS_CONTROLLER=y
    INGRESS_CLASS_NAME="nginx"
fi


if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
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
else
    PROTOCOL=http
fi

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

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    read -p $'\t- What is the preferred domain for reaching the UI (default: syntho.company.com): ' DOMAIN
    DOMAIN=${DOMAIN:-syntho.company.com}
else
    DOMAIN=syntho.company.com
fi

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- How much CPU resource you would like to use for the ray head (e.g., 32000m) (default: 1000m): ' CPU_RESOURCE_RAY_HEAD
        CPU_RESOURCE_RAY_HEAD=${CPU_RESOURCE_RAY_HEAD:-1000m}

        # Use regex to check if the input matches the desired format
        if [[ $CPU_RESOURCE_RAY_HEAD =~ ^[0-9]+m$ ]]; then
            break
        else
            echo "Invalid input format. Please enter a positive integer followed by 'm'."
        fi
    done
else
    CPU_RESOURCE_RAY_HEAD=1000m
fi

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- How much memory resource you would like to use for the ray head (e.g., 16G) (default: 4G): ' MEMORY_RESOURCE_RAY_HEAD
        MEMORY_RESOURCE_RAY_HEAD=${MEMORY_RESOURCE_RAY_HEAD:-4G}

        # Use regex to check if the input matches the desired format
        if [[ $MEMORY_RESOURCE_RAY_HEAD =~ ^[0-9]+G$ ]]; then
            break
        else
            echo "Invalid input format. Please enter a positive integer followed by 'G'."
        fi
    done
else
    MEMORY_RESOURCE_RAY_HEAD=4G
fi

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- Login E-mail (default: admin@company.com): ' UI_ADMIN_LOGIN_EMAIL
        UI_ADMIN_LOGIN_EMAIL=${UI_ADMIN_LOGIN_EMAIL:-admin@company.com}

        # Use regex to check if the input matches the desired format
        if [[ $UI_ADMIN_LOGIN_EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Invalid input format. Please enter a proper email address."
        fi
    done
else
    UI_ADMIN_LOGIN_EMAIL=admin@company.com
fi

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- Login Password (default: password!): ' UI_ADMIN_LOGIN_PASSWORD
        UI_ADMIN_LOGIN_PASSWORD=${UI_ADMIN_LOGIN_PASSWORD:-password!}

        # Use regex to check if the input matches the desired format
        if [[ $UI_ADMIN_LOGIN_PASSWORD =~ ^.{8,}$ ]]; then
            break
        else
            echo "Invalid input format. Password should be at least 8 characters long."
        fi
    done
else
    UI_ADMIN_LOGIN_PASSWORD=password!
fi


cat << EOF > "$DEPLOYMENT_DIR/.config.env"
LICENSE_KEY=$LICENSE_KEY
STORAGE_CLASS_NAME=$STORAGE_CLASS_NAME
STORAGE_ACCESS_MODE=$STORAGE_ACCESS_MODE
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

cat << EOF > "$DEPLOYMENT_DIR/.auth.env"
UI_ADMIN_LOGIN_EMAIL=$UI_ADMIN_LOGIN_EMAIL
UI_ADMIN_LOGIN_PASSWORD=$UI_ADMIN_LOGIN_PASSWORD
EOF
