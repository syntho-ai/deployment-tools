#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"
SKIP_CONFIGURATION="$SKIP_CONFIGURATION"
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


# for ray cluster
LICENSE_KEY="$LICENSE_KEY"
RAY_OPERATOR_IMG_REPO="$RAY_OPERATOR_IMG_REPO"
RAY_OPEARATOR_IMG_TAG="$RAY_OPEARATOR_IMG_TAG"
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
SYNTHO_UI_CORE_IMG_VER="$SYNTHO_UI_CORE_IMG_VER"
SYNTHO_UI_BACKEND_IMG_REPO="$SYNTHO_UI_BACKEND_IMG_REPO"
SYNTHO_UI_BACKEND_IMG_VER="$SYNTHO_UI_BACKEND_IMG_VER"
SYNTHO_UI_FRONTEND_IMG_REPO="$SYNTHO_UI_FRONTEND_IMG_REPO"
SYNTHO_UI_FRONTEND_IMG_VER="$SYNTHO_UI_FRONTEND_IMG_VER"
INGRESS_CONTROLLER="$INGRESS_CONTROLLER"
TLS_ENABLED="$TLS_ENABLED"
STORAGE_CLASS_NAME="$STORAGE_CLASS_NAME"
PV_LABEL_KEY="$PV_LABEL_KEY"


generate_ray_values() {
    local TEMPLATE_FILE="$CHARTS_DIR/ray/values.yaml.tpl"
    local OUTPUT_FILE="$CHARTS_DIR/ray/values-generated.yaml"

    sed "s|{{ LICENSE_KEY }}|$LICENSE_KEY|g; \
         s|{{ RAY_OPERATOR_IMG_REPO }}|$RAY_OPERATOR_IMG_REPO|g; \
         s|{{ RAY_OPEARATOR_IMG_TAG }}|$RAY_OPEARATOR_IMG_TAG|g; \
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
         s|{{ SYNTHO_UI_CORE_IMG_VER }}|$SYNTHO_UI_CORE_IMG_VER|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_REPO }}|$SYNTHO_UI_BACKEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_BACKEND_IMG_VER }}|$SYNTHO_UI_BACKEND_IMG_VER|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_REPO }}|$SYNTHO_UI_FRONTEND_IMG_REPO|g; \
         s|{{ SYNTHO_UI_FRONTEND_IMG_VER }}|$SYNTHO_UI_FRONTEND_IMG_VER|g; \
         s|{{ INGRESS_CONTROLLER }}|$INGRESS_CONTROLLER|g; \
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
        local INGRESS_CONTROLLER_NAMESPACE="syntho-ingress-nginx"
        local DOMAIN="$DOMAIN"

        kubectl run -i --tty --rm busybox-2 --image=busybox --restart=Never --namespace syntho -- /bin/sh -c "wget -O- \
        --header=\"Host: $DOMAIN\" --server-response \
        http://$INGRESS_CONTROLLER_SERVICE_NAME.$INGRESS_CONTROLLER_NAMESPACE.svc.cluster.local/login/ \
        2>&1 | grep 'HTTP/' | awk '{print \$2}'" | grep -q 200
    }

    while ! is_200; do
        echo "no"
        sleep 5
    done
    echo "yes"
}

deploy_ray_cluster() {
    local errors=""
    sleep 2

    if ! generate_ray_values >/dev/null 2>&1; then
        errors+="values.yaml generation error for the Ray Cluster\n"
    fi

    if ! deploy_ray >/dev/null 2>&1; then
        errors+="Ray Cluster deployment has been unexpectedly failed\n"
    fi

    if ! wait_for_ray_cluster_health >/dev/null 2>&1; then
        errors+="Ray Cluster health check has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

deploy_syntho_ui() {
    local errors=""


    if ! generate_synthoui_values >/dev/null 2>&1; then
        errors+="values.yaml generation error for the Syntho Stack\n"
    fi

    if ! deploy_synthoui >/dev/null 2>&1; then
        errors+="Syntho Stack deployment has been unexpectedly failed\n"
    fi

    if ! wait_for_synthoui_health >/dev/null 2>&1; then
        errors+="Syntho UI health check has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

wait_local_nginx_ingress_controller() {
    local errors=""


    if ! wait_local_nginx >/dev/null 2>&1; then
        errors+="Nginx controller health check has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

all_logs() {
    sleep 5

    NAMESPACE="syntho"
    OUTPUT_DIR="/tmp"
    LOG_OUTPUT_FILE="${SHARED}/syntho-all-logs.txt"
    DESCRIBE_OUTPUT_FILE="${SHARED}/syntho-all-describes.txt"
    EXISTING_TARBALL="/tmp/syntho-all-logs.tar.gz"
    rm -f "$LOG_OUTPUT_FILE" "$DESCRIBE_OUTPUT_FILE" "$EXISTING_TARBALL"

    PODS=($(kubectl --kubeconfig $KUBECONFIG get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'))

    for POD in $PODS; do
        echo "Logs for Pod: $POD" >> $LOG_OUTPUT_FILE

        kubectl --kubeconfig $KUBECONFIG logs $POD -n $NAMESPACE --all-containers >> $LOG_OUTPUT_FILE
        echo "----------------------------------------" >> $LOG_OUTPUT_FILE

        echo "Describe for Pod: $POD" >> $DESCRIBE_OUTPUT_FILE
        kubectl --kubeconfig $KUBECONFIG describe pod $POD -n $NAMESPACE >> $DESCRIBE_OUTPUT_FILE
        echo "----------------------------------------" >> $DESCRIBE_OUTPUT_FILE
    done

    tar -czvf "/tmp/syntho-all-logs.tar.gz" -C "$SHARED" syntho-all-logs.txt syntho-all-describes.txt
}

get_all_logs() {

    if ! all_logs >/dev/null 2>&1; then
        errors+="Preparing all logs has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}

deployment_failure_callback() {
    with_loading "Please wait until the necessary materials are being prepared for diagnosis" get_all_logs "" "" 2
    with_loading "Please share this file (/tmp/syntho-all-logs.tar.gz) with support@syntho.ai" do_nothing "" "" 2
}


with_loading "Deploying Ray Cluster" deploy_ray_cluster 600 deployment_failure_callback
with_loading "Deploying Syntho Stack" deploy_syntho_ui 600 deployment_failure_callback


if [[ ($DEPLOY_INGRESS_CONTROLLER == "y" && $PROTOCOL == "http") || ($SKIP_CONFIGURATION == "true") ]]; then
    with_loading "Waiting ingress controller to be ready for accessing the UI (this might take some time)" wait_local_nginx_ingress_controller

    TMP_KUBECONFIG_DIR="/tmp/.kube-for-syntho"
    TMP_KUBECONFIG="/tmp/.kube-for-syntho/config"
    rm -f "$TMP_KUBECONFIG_DIR"
    mkdir -p "$TMP_KUBECONFIG_DIR"
    cp "$KUBECONFIG" "$TMP_KUBECONFIG"


    echo -e '
'"${YELLOW}"'################### For Local Development ################################'"${NC}"'

kubectl --kubeconfig '"$TMP_KUBECONFIG"' port-forward service/syntho-ingress-nginx-controller 32282:80 -n syntho-ingress-nginx
echo "127.0.0.1    '"$DOMAIN"'" | sudo tee -a /etc/hosts

'"${GREEN}"'visit:'"${NC}"' http://'"$DOMAIN"':32282
'"${YELLOW}"'################### For Local Development ################################'"${NC}"'
'
fi

echo -e "${YELLOW}Syntho stack got deployed. ${GREEN}Please visit:${NC} $PROTOCOL://$DOMAIN${NC}"
echo -e "${YELLOW}PS: Make sure the DNS configuration is made properly on your side!${NC}"
