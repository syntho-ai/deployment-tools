#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"
USE_TRUSTED_REGISTRY="$USE_TRUSTED_REGISTRY"
IMAGE_PULL_SECRET="$IMAGE_PULL_SECRET"
source $DEPLOYMENT_DIR/.config.env --source-only
source $DEPLOYMENT_DIR/.images.env --source-only
ARCH="$ARCH"
if [[ "$ARCH" == "arm" ]]; then
    source $DEPLOYMENT_DIR/.images-arm.env --source-only
fi
source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
CHARTS_DIR="$CHARTS_DIR"
DEPLOY_INGRESS_CONTROLLER="$DEPLOY_INGRESS_CONTROLLER"
source $DEPLOYMENT_DIR/.resources.env --source-only
SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
source $DEPLOYMENT_DIR/.auth.env --source-only
UI_LOGIN_EMAIL="${UI_ADMIN_LOGIN_EMAIL}"
UI_LOGIN_PASSWORD="${UI_ADMIN_LOGIN_PASSWORD}"

source $DEPLOYMENT_DIR/.k8s-cluster-info.env --source-only
NUM_OF_NODES=$NUM_OF_NODES
IS_MANAGED="$IS_MANAGED"

SHARED="$DEPLOYMENT_DIR/shared"
mkdir -p "$SHARED"
SYNTHO_CLI_PROCESS_DIR="$SHARED/process"
mkdir -p "$SYNTHO_CLI_PROCESS_DIR"

if [[ "$USE_TRUSTED_REGISTRY" == "true" ]]; then
    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/override_image_urls_and_tags_with_trusted_registry.log"

    # using trusted registry
    echo "USE_TRUSTED_REGISTRY: $USE_TRUSTED_REGISTRY" >> $SYNTHO_CLI_PROCESS_LOGS
    if [[ "$USE_TRUSTED_REGISTRY" == "true" ]]; then
        echo "using trusted image registry instead" >> $SYNTHO_CLI_PROCESS_LOGS
        echo $(cat $PREPULL_IMAGES_DIR/.images-trusted.env) >> $SYNTHO_CLI_PROCESS_LOGS
        PREPULL_IMAGES_DIR="$PREPULL_IMAGES_DIR"
        # Read the .image-trusted.env file line by line
        while IFS='=' read -r key value; do
            # Remove the "TRUSTED_" prefix
            new_key=${key#TRUSTED_}
            # Export the variable with the new name
            export $new_key="$value"
        done < $PREPULL_IMAGES_DIR/.images-trusted.env
        echo "env vars are overridden with trusted registry info" >> $SYNTHO_CLI_PROCESS_LOGS
    fi
fi

SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/active_image_pull_secret_info.log"
ACTIVE_IMAGE_PULL_SECRET="syntho-cr-secret"
if [[ "$USE_TRUSTED_REGISTRY" == "true" ]]; then
    ACTIVE_IMAGE_PULL_SECRET=""
    if [[ "$IMAGE_PULL_SECRET" != "" ]]; then
        ACTIVE_IMAGE_PULL_SECRET="$IMAGE_PULL_SECRET"
    fi
fi
echo "final image pull secret is: $ACTIVE_IMAGE_PULL_SECRET" >> $SYNTHO_CLI_PROCESS_LOGS


# for ray cluster
LICENSE_KEY="$LICENSE_KEY"
RAY_OPERATOR_IMG_REPO="$RAY_OPERATOR_IMG_REPO"
RAY_OPERATOR_IMG_TAG="$RAY_OPERATOR_IMG_TAG"
RAY_IMAGE_IMG_REPO="$RAY_IMAGE_IMG_REPO"
RAY_IMAGE_IMG_TAG="$RAY_IMAGE_IMG_TAG"
RAY_HEAD_CPU_LIMIT="$RAY_HEAD_CPU_LIMIT"
RAY_HEAD_MEMORY_LIMIT="$RAY_HEAD_MEMORY_LIMIT"
RAY_HEAD_CPU_REQUESTS="$RAY_HEAD_CPU_REQUESTS"
RAY_HEAD_MEMORY_REQUESTS="$RAY_HEAD_MEMORY_REQUESTS"
RAY_WORKER_CPU_LIMIT="$RAY_WORKER_CPU_LIMIT"
RAY_WORKER_MEMORY_LIMIT="$RAY_WORKER_MEMORY_LIMIT"
RAY_WORKER_CPU_REQUESTS="$RAY_WORKER_CPU_REQUESTS"
RAY_WORKER_MEMORY_REQUESTS="$RAY_WORKER_MEMORY_REQUESTS"
PV_LABEL_KEY="$PV_LABEL_KEY"
STORAGE_CLASS_NAME="$STORAGE_CLASS_NAME"
STORAGE_ACCESS_MODE="$STORAGE_ACCESS_MODE"

# for syntho ui
DOMAIN="$DOMAIN"
PROTOCOL="$PROTOCOL"
LICENSE_KEY="$LICENSE_KEY"
SYNTHO_UI_CORE_IMG_REPO="$SYNTHO_UI_CORE_IMG_REPO"
SYNTHO_UI_CORE_IMG_TAG="$SYNTHO_UI_CORE_IMG_TAG"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_TAG="$SYNTHO_UI_BACKEND_IMG_TAG"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_TAG="$SYNTHO_UI_FRONTEND_IMG_TAG"
POSTGRES_IMG_REPO="$POSTGRES_IMG_REPO"
POSTGRES_IMG_TAG="$POSTGRES_IMG_TAG"
REDIS_IMG_REPO="$REDIS_IMG_REPO"
REDIS_IMG_TAG="$REDIS_IMG_TAG"
INGRESS_CONTROLLER="$INGRESS_CONTROLLER"
TLS_ENABLED="$TLS_ENABLED"
STORAGE_CLASS_NAME="$STORAGE_CLASS_NAME"
PV_LABEL_KEY="$PV_LABEL_KEY"


generate_ray_values() {
    local TEMPLATE_FILE="$CHARTS_DIR/ray/values.yaml.tpl"
    local OUTPUT_FILE="$CHARTS_DIR/ray/values-generated.yaml"

    sed "s|{{ LICENSE_KEY }}|$LICENSE_KEY|g; \
         s|{{ RAY_OPERATOR_IMG_REPO }}|$RAY_OPERATOR_IMG_REPO|g; \
         s|{{ RAY_OPERATOR_IMG_TAG }}|$RAY_OPERATOR_IMG_TAG|g; \
         s|{{ RAY_IMAGE_IMG_REPO }}|$RAY_IMAGE_IMG_REPO|g; \
         s|{{ RAY_IMAGE_IMG_TAG }}|$RAY_IMAGE_IMG_TAG|g; \
         s|{{ RAY_HEAD_CPU_LIMIT }}|$RAY_HEAD_CPU_LIMIT|g; \
         s|{{ RAY_HEAD_MEMORY_LIMIT }}|$RAY_HEAD_MEMORY_LIMIT|g; \
         s|{{ RAY_HEAD_CPU_REQUESTS }}|$RAY_HEAD_CPU_REQUESTS|g; \
         s|{{ RAY_HEAD_MEMORY_REQUESTS }}|$RAY_HEAD_MEMORY_REQUESTS|g; \
         s|{{ RAY_WORKER_CPU_LIMIT }}|$RAY_WORKER_CPU_LIMIT|g; \
         s|{{ RAY_WORKER_MEMORY_LIMIT }}|$RAY_WORKER_MEMORY_LIMIT|g; \
         s|{{ RAY_WORKER_CPU_REQUESTS }}|$RAY_WORKER_CPU_REQUESTS|g; \
         s|{{ RAY_WORKER_MEMORY_REQUESTS }}|$RAY_WORKER_MEMORY_REQUESTS|g; \
         s|{{ PV_LABEL_KEY }}|$PV_LABEL_KEY|g; \
         s|{{ IMAGE_PULL_SECRET }}|$ACTIVE_IMAGE_PULL_SECRET|g; \
         s|{{ STORAGE_CLASS_NAME }}|$STORAGE_CLASS_NAME|g; \
         s|{{ STORAGE_ACCESS_MODE }}|$STORAGE_ACCESS_MODE|g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"
}

deploy_ray() {
    local VALUES_YAML="$CHARTS_DIR/ray/values-generated.yaml"
    local RAY_CHARTS="$CHARTS_DIR/ray"
    helm --kubeconfig $KUBECONFIG install ray-cluster $RAY_CHARTS --values $VALUES_YAML --namespace syntho
}

wait_for_ray_cluster_health() {
    local POD_PREFIX=ray-cluster-head

    is_pod_running() {
        kubectl --kubeconfig $KUBECONFIG get pod -n syntho | grep "^$POD_PREFIX" | grep -q "Running"
    }

    is_cluster_healthy() {
        local POD_NAME=$(kubectl --kubeconfig $KUBECONFIG get pod -n syntho | grep "^$POD_PREFIX" | awk '{print $1}')

        if [ -n "$POD_NAME" ]; then
            local CONTENT=$(kubectl --kubeconfig $KUBECONFIG -n syntho exec -ti $POD_NAME -- /bin/bash -c "ray status")
            echo $CONTENT | grep -q "(no failures)" && echo $CONTENT | grep -q "(no pending nodes)"
        fi
    }

    while ! is_pod_running; do
        sleep 5
    done

    while ! is_cluster_healthy; do
        sleep 5
    done
}

generate_synthoui_values() {
    local TEMPLATE_FILE="$CHARTS_DIR/syntho-ui/values.yaml.tpl"
    local OUTPUT_FILE="$CHARTS_DIR/syntho-ui/values-generated.yaml"

    sed "s|{{ DOMAIN }}|$DOMAIN|g; \
         s|{{ PROTOCOL }}|$PROTOCOL|g; \
         s|{{ LICENSE_KEY }}|$LICENSE_KEY|g; \
         s|{{ SYNTHO_UI_CORE_IMG_REPO }}|$SYNTHO_UI_CORE_IMG_REPO|g; \
         s|{{ SYNTHO_UI_CORE_IMG_TAG }}|$SYNTHO_UI_CORE_IMG_TAG|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_REPO }}|$SYNTHO_UI_BACKEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_TAG }}|$SYNTHO_UI_BACKEND_IMG_TAG|g; \
         s|{{ UI_LOGIN_EMAIL }}|$UI_LOGIN_EMAIL|g; \
         s|{{ UI_LOGIN_PASSWORD }}|$UI_LOGIN_PASSWORD|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_REPO }}|$SYNTHO_UI_FRONTEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_TAG }}|$SYNTHO_UI_FRONTEND_IMG_TAG|g; \
         s|{{ POSTGRES_IMG_REPO }}|$POSTGRES_IMG_REPO|g; \
         s|{{ POSTGRES_IMG_TAG }}|$POSTGRES_IMG_TAG|g; \
         s|{{ REDIS_IMG_REPO }}|$REDIS_IMG_REPO|g; \
         s|{{ REDIS_IMG_TAG }}|$REDIS_IMG_TAG|g; \
         s|{{ INGRESS_CONTROLLER }}|$INGRESS_CONTROLLER|g; \
         s|{{ IMAGE_PULL_SECRET }}|$ACTIVE_IMAGE_PULL_SECRET|g; \
         s|{{ TLS_ENABLED }}|$TLS_ENABLED|g; \
         s|{{ STORAGE_CLASS_NAME }}|$STORAGE_CLASS_NAME|g; \
         s|{{ PV_LABEL_KEY }}|$PV_LABEL_KEY|g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"
}

deploy_synthoui() {
    local VALUES_YAML="$CHARTS_DIR/syntho-ui/values-generated.yaml"
    local RAY_CHARTS="$CHARTS_DIR/syntho-ui"
    helm --kubeconfig $KUBECONFIG install syntho-ui $RAY_CHARTS --values $VALUES_YAML --namespace syntho
}

wait_for_synthoui_health() {
    local POD_PREFIX=frontend-

    is_pod_running() {
        kubectl --kubeconfig $KUBECONFIG get pod -n syntho | grep "^$POD_PREFIX" | grep -q "Running"
    }

    is_frontend_healthy() {
        local POD_NAME=$(kubectl --kubeconfig $KUBECONFIG get pod -n syntho | grep "^$POD_PREFIX" | awk '{print $1}')
        content=""

        if [ -n "$POD_NAME" ]; then
            content=$(kubectl --kubeconfig $KUBECONFIG -n syntho exec -i $POD_NAME -- /bin/sh -c "wget -q --spider --server-response http://0.0.0.0:3000" 2>&1)
        fi

        echo "$content" | grep -q "HTTP/1.1 200 OK"
    }

    while ! is_pod_running; do
        echo "frontend not running yet"
        sleep 5
    done

    echo "waiting before making request to frontend"
    sleep 5

    while ! is_frontend_healthy; do
        echo "frontend not healthy yet"
        sleep 5
    done
}

wait_local_nginx() {
    is_200() {
        local INGRESS_CONTROLLER_SERVICE_NAME="syntho-ingress-nginx-controller"
        local INGRESS_CONTROLLER_NAMESPACE="syntho"
        local DOMAIN="$DOMAIN"

        kubectl run -i --tty --rm busybox-2 --image=busybox --restart=Never --namespace syntho -- /bin/sh -c "wget -O- \
        --header=\"Host: $DOMAIN\" --server-response \
        http://$INGRESS_CONTROLLER_SERVICE_NAME.$INGRESS_CONTROLLER_NAMESPACE.svc.cluster.local/login/ \
        2>&1 | grep 'HTTP/' | awk '{print \$2}'" | grep -q 200
    }

    while ! is_200; do
        echo "ingress controller is not ready yet"
        sleep 5
    done
    echo "yes"
}

generate_image_pull_secrets_from_original() {
    SECRET_NAME="$IMAGE_PULL_SECRET"
    SECRET_NAMESPACE=$(kubectl --kubeconfig $KUBECONFIG get secrets --all-namespaces | grep $SECRET_NAME | awk '{print $1}')

    # Check if the SECRET_NAMESPACE is empty
    if [ -z "$SECRET_NAMESPACE" ]; then
        echo "Error: secret '$SECRET_NAME' does not exist in any namespace"
        return 1
    fi

    echo "secret name: $SECRET_NAME"
    echo "secret namespace: $SECRET_NAMESPACE"

    NEW_SECRET_NAMESPACE=syntho
    echo "new secret namespace: $NEW_SECRET_NAMESPACE"

    echo "secret for image pulling is being created"
    kubectl --kubeconfig $KUBECONFIG get secret $SECRET_NAME -n $SECRET_NAMESPACE -o yaml | \
        grep -v '^  resourceVersion:' | \
        grep -v '^  selfLink:' | \
        grep -v '^  uid:' | \
        grep -v '^  creationTimestamp:' | \
        sed "s/namespace: ${SECRET_NAMESPACE}/namespace: ${NEW_SECRET_NAMESPACE}/g" > $DEPLOYMENT_DIR/trusted-registry-image-pull-secret.yaml

    kubectl --kubeconfig $KUBECONFIG --namespace $NEW_SECRET_NAMESPACE apply -f $DEPLOYMENT_DIR/trusted-registry-image-pull-secret.yaml
    echo "secret for image pulling was created successfully"
}

prepare_for_trusted_registry() {
    local errors=""
    sleep 2

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/prepare_for_trusted_registry.log"

    echo "prepare_for_trusted_registry:generate_image_pull_secrets_from_original has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! generate_image_pull_secrets_from_original >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="image pull secrets for trusted registry access couldn't be copied under syntho namespace\n"
    fi
    echo "prepare_for_trusted_registry:generate_image_pull_secrets_from_original has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    write_and_exit "$errors" "prepare_for_trusted_registry"

}

deploy_ray_cluster() {
    local errors=""
    sleep 2

    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/deploy_ray_cluster.log"

    echo "deploy_ray_cluster:generate_ray_values has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! generate_ray_values >/dev/null 2>&1; then
        errors+="values.yaml generation error for the Ray Cluster\n"
    fi
    echo "deploy_ray_cluster:generate_ray_values has been done" >> $SYNTHO_CLI_PROCESS_LOGS


    echo "deploy_ray_cluster:deploy_ray has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! deploy_ray >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Ray Cluster deployment has been unexpectedly failed\n"
    fi
    echo "deploy_ray_cluster:deploy_ray has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    echo "deploy_ray_cluster:wait_for_ray_cluster_health has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! wait_for_ray_cluster_health >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Ray Cluster health check has been unexpectedly failed\n"
    fi
    echo "deploy_ray_cluster:wait_for_ray_cluster_health has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    write_and_exit "$errors" "deploy_ray_cluster"
}

deploy_syntho_ui() {
    local errors=""
    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/deploy_syntho_ui.log"

    echo "deploy_syntho_ui:generate_synthoui_values has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! generate_synthoui_values >/dev/null 2>&1; then
        errors+="values.yaml generation error for the Syntho Stack\n"
    fi
    echo "deploy_syntho_ui:generate_synthoui_values has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    echo "deploy_syntho_ui:deploy_synthoui has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! deploy_synthoui >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Syntho Stack deployment has been unexpectedly failed\n"
    fi
    echo "deploy_syntho_ui:deploy_synthoui has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    echo "deploy_syntho_ui:wait_for_synthoui_health has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! wait_for_synthoui_health >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Syntho UI health check has been unexpectedly failed\n"
    fi
    echo "deploy_syntho_ui:wait_for_synthoui_health has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    write_and_exit "$errors" "deploy_syntho_ui"
}

wait_local_nginx_ingress_controller() {
    local errors=""
    SYNTHO_CLI_PROCESS_LOGS="$SYNTHO_CLI_PROCESS_DIR/wait_local_nginx_ingress_controller.log"

    echo "wait_local_nginx_ingress_controller:wait_local_nginx has been started" >> $SYNTHO_CLI_PROCESS_LOGS
    if ! wait_local_nginx >> $SYNTHO_CLI_PROCESS_LOGS 2>&1; then
        errors+="Nginx controller health check has been unexpectedly failed\n"
    fi
    echo "wait_local_nginx_ingress_controller:wait_local_nginx has been done" >> $SYNTHO_CLI_PROCESS_LOGS

    write_and_exit "$errors" "wait_local_nginx_ingress_controller"
}

all_logs() {
    sleep 5

    NAMESPACE="syntho"
    OUTPUT_DIR="/tmp/syntho"
    LOGS_DIR="$SHARED/logs"
    TARBALL="$OUTPUT_DIR/diagnosis-k8s.tar.gz"
    rm -rf "$OUTPUT_DIR" "$LOGS_DIR"
    mkdir -p "$OUTPUT_DIR" "$LOGS_DIR"

    PODS=($(kubectl --kubeconfig $KUBECONFIG get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'))
    echo "${PODS[@]}" > "$LOGS_DIR/pods"

    for POD in "${PODS[@]}"; do
        kubectl --kubeconfig $KUBECONFIG logs $POD -n $NAMESPACE --all-containers > "$LOGS_DIR/$POD.log"
        kubectl --kubeconfig $KUBECONFIG describe pod $POD -n $NAMESPACE > "$LOGS_DIR/$POD.describe"
    done

    tar -czvf "$TARBALL" -C "$LOGS_DIR" .
}

get_all_logs() {

    if ! all_logs >/dev/null 2>&1; then
        errors+="Preparing all logs has been unexpectedly failed\n"
    fi

    write_and_exit "$errors" "get_all_logs"
}

deployment_failure_callback() {
    with_loading "Please wait until the necessary materials are being prepared for diagnosis" get_all_logs "" "" 2
    with_loading "Please share this file (/tmp/syntho/diagnosis-k8s.tar.gz) with support@syntho.ai" do_nothing "" "" 2
}


if [[ "$USE_TRUSTED_REGISTRY" == "true"  && "$IMAGE_PULL_SECRET" != "" ]]; then
    with_loading "Preparing Deployment Ecosystem for Trusted Registry Usage" prepare_for_trusted_registry
fi
with_loading "Deploying Ray Cluster" deploy_ray_cluster 600 deployment_failure_callback
with_loading "Deploying Syntho Stack" deploy_syntho_ui 600 deployment_failure_callback


if [[ ($DEPLOY_INGRESS_CONTROLLER == "y" && $PROTOCOL == "http") || ($SKIP_CONFIGURATION == "true") ]]; then
    with_loading "Waiting ingress controller to be ready for accessing the UI (this might take some time)" wait_local_nginx_ingress_controller

    if [[ $IS_MANAGED == "false" ]] && [[ $NUM_OF_NODES -eq 1 ]]; then
        TMP_KUBECONFIG_DIR="/tmp/.kube-for-syntho"
        TMP_KUBECONFIG="/tmp/.kube-for-syntho/config"
        rm -rf "$TMP_KUBECONFIG_DIR"
        mkdir -p "$TMP_KUBECONFIG_DIR"
        cp "$KUBECONFIG" "$TMP_KUBECONFIG"

        echo -e '
'"${YELLOW}"'################### For Local Experimentation ################################'"${NC}"'

kubectl --kubeconfig '"$TMP_KUBECONFIG"' port-forward service/syntho-ingress-nginx-controller 32282:80 -n syntho
echo "127.0.0.1    '"$DOMAIN"'" | sudo tee -a /etc/hosts

'"${GREEN}"'visit:'"${NC}"' http://'"$DOMAIN"':32282
'"${YELLOW}"'################### For Local Experimentation ################################'"${NC}"'
'
    fi
fi

echo -e '
'"${YELLOW}Syntho stack got deployed. ${GREEN}Please visit:${NC} $PROTOCOL://$DOMAIN${NC}"'
'"${YELLOW}- Email: $UI_LOGIN_EMAIL"'
'"${YELLOW}- Password: $UI_LOGIN_PASSWORD"'
'"${YELLOW}PS: Make sure the DNS configuration is made properly on your side!${NC}"'
'
