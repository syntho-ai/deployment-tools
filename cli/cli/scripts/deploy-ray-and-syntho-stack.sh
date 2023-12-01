#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
KUBECONFIG="$KUBECONFIG"
source $DEPLOYMENT_DIR/.config.env --source-only
source $DEPLOYMENT_DIR/.images.env --source-only
ARCH="$ARCH"
if [[ "$ARCH" == "arm" ]]; then
    source $DEPLOYMENT_DIR/.images-arm.env --source-only
fi
source $DEPLOYMENT_DIR/.pre.deployment.ops.env --source-only
CHARTS_DIR="$CHARTS_DIR"
source $DEPLOYMENT_DIR/.resources.env --source-only


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

deploy_ray_cluster() {
    local errors=""


    if ! generate_ray_values >/dev/null 2>&1; then
        errors+="Error: values.yaml generation error for the Ray Cluster\n"
    fi

    if ! deploy_ray >/dev/null 2>&1; then
        errors+="Error: Ray Cluster deployment has been unexpectedly failed\n"
    fi

    if ! wait_for_ray_cluster_health >/dev/null 2>&1; then
        errors+="Error: Ray Cluster health check has been unexpectedly failed\n"
    fi

    echo -n "$errors"
}



with_loading "Deploying Ray Cluster (this might take some time)" deploy_ray_cluster 2
