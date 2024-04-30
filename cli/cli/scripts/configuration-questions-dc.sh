#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only

LICENSE_KEY="$LICENSE_KEY"
REGISTRY_USER="$REGISTRY_USER"
REGISTRY_PWD="$REGISTRY_PWD"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"


if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- How much CPU resource you would like to use for the ray head (e.g., 32) (default: 1): ' RAY_CPUS
        RAY_CPUS=${RAY_CPUS:-1}

        # Use regex to check if the input matches the desired format
        if [[ $RAY_CPUS =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid input format. Please enter a positive integer."
        fi
    done
else
    RAY_CPUS=1
fi

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    while true; do
        read -p $'\t- How much memory resource you would like to use for the ray head (e.g., 16G) (default: 4G): ' RAY_MEMORY
        RAY_MEMORY=${RAY_MEMORY:-4G}

        # Use regex to check if the input matches the desired format
        if [[ $RAY_MEMORY =~ ^[0-9]+G$ ]]; then
            break
        else
            echo "Invalid input format. Please enter a positive integer followed by 'G'."
        fi
    done
else
    RAY_MEMORY=4G
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

if [[ "$SKIP_CONFIGURATION" == "false" ]]; then
    read -p $'\t- What is the preferred domain for reaching the UI (eg. localhost, 127.0.0.1, your.company.domain, 192.168.1.34) (default: localhost): ' DOMAIN
    DOMAIN=${DOMAIN:-localhost}
else
    DOMAIN=localhost
fi


cat << EOF > "$DEPLOYMENT_DIR/.config.env"
LICENSE_KEY=$LICENSE_KEY
DOMAIN=$DOMAIN
EOF

cat << EOF > "$DEPLOYMENT_DIR/.resources.env"
RAY_CPUS=$RAY_CPUS
RAY_MEMORY=$RAY_MEMORY
EOF

cat << EOF > "$DEPLOYMENT_DIR/.auth.env"
UI_ADMIN_LOGIN_USERNAME=admin
UI_ADMIN_LOGIN_EMAIL=$UI_ADMIN_LOGIN_EMAIL
UI_ADMIN_LOGIN_PASSWORD=$UI_ADMIN_LOGIN_PASSWORD
EOF
