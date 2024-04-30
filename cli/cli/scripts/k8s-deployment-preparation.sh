#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/utils.sh" --source-only

while true; do
    read -p $'\t- Do you want to provide your own kubeconfig for Syntho stack deployment? (y/N): ' ANSWER
    ANSWER=${ANSWER:-N}

    case "$ANSWER" in
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

if [[ $ANSWER == "y" || $ANSWER == "Y" ]]; then
  echo -e "\n${BOLD_WHITE}It is expected to be provided via 'syntho-cli k8s deployment --kubeconfig $KUBECONFIG ...'${NC}"
  echo -e "${BOLD_WHITE}Next steps: 'syntho-cli k8s deployment --help'${NC}"
  exit 0
fi


while true; do
    read -p $'\t- What is the k8s cluster name: ' CLUSTER_NAME

    if [[ ${#CLUSTER_NAME} -ge 5 ]] && [[ "$CLUSTER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        break
    else
        echo "Invalid input. Cluster name should be at least 5 characters long and contain only letters, numbers, underscores, and hyphens."
    fi
done


while true; do
    read -p $'\t- Please provide the server URL: ' SERVER_URL

    # Regular expression to check if SERVER_URL is in URL format
    URL_REGEX="^(http|https)://[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+([/?].*)?$|^(http|https)://[0-9]+(\.[0-9]+){3}:[0-9]+([/?].*)?$"

    if [[ "$SERVER_URL" =~ $URL_REGEX ]]; then
        break
    else
        echo "Invalid input. Please enter a valid server URL."
    fi
done

bash_script_content=$(cat <<EOF
#!/bin/bash

# Define variables
namespace="syntho"
service_account="syntho-sa"

# Function to check if a namespace exists
namespace_exists() {
  local namespace=\$1
  kubectl get namespace \$namespace &> /dev/null
}

# Function to check if a service account exists in a namespace
service_account_exists() {
  local namespace=\$1
  local service_account=\$2
  kubectl get serviceaccount \$service_account -n \$namespace &> /dev/null
}

# Function to create a namespace if it doesn't exist
create_namespace() {
  local namespace=\$1
  if ! namespace_exists \$namespace; then
    kubectl create namespace \$namespace
  fi
}

# Function to create a service account if it doesn't exist
create_service_account() {
  local namespace=\$1
  local service_account=\$2
  if ! service_account_exists \$namespace \$service_account; then
    kubectl create serviceaccount \$service_account -n \$namespace
  fi
}

# Function to grant a powerful privilege to a service account
grant_privilege() {
  local namespace=\$1
  local service_account=\$2
  kubectl create clusterrolebinding \$service_account-binding --clusterrole=cluster-admin --serviceaccount=\$namespace:\$service_account
}

# Function to generate a token for a service account
generate_token() {
  local namespace=\$1
  local service_account=\$2
  kubectl get secret \$(kubectl get serviceaccount \$service_account -n \$namespace -o jsonpath='{.secrets[0].name}') -n \$namespace -o jsonpath='{.data.token}' | base64 --decode
}

# Function to generate kubeconfig content
generate_kubeconfig_content() {
  local cluster_name=\$1
  local server_url=\$2
  local token=\$3
  cat <<EOFF
apiVersion: v1
kind: Config
clusters:
- name: \$cluster_name
  cluster:
    server: \$server_url
contexts:
- name: syntho-context
  context:
    cluster: \$cluster_name
    user: syntho-user
    namespace: syntho
users:
- name: syntho-user
  user:
    token: \$token
current-context: syntho-context
EOFF
}

# Main script

# Create syntho namespace
create_namespace "\$namespace"

# Create syntho service account
create_service_account "\$namespace" "\$service_account"

# Grant privilege to syntho service account
grant_privilege "\$namespace" "\$service_account"

# Generate token for syntho service account
token=\$(generate_token "\$namespace" "\$service_account")

# Generate kubeconfig content
kubeconfig_content=\$(generate_kubeconfig_content "$CLUSTER_NAME" "$SERVER_URL" "\$token")

echo "Kubeconfig content:"
echo "\$kubeconfig_content"
EOF
)

echo -e "\n${BOLD_WHITE} When below script is ran on a cluster where Syntho stack is going to be
deployed on, it will generate a KUBECONFIG and it can be used in only 'syntho-cli' to manage
kubernetes resources${NC}"
echo -e "\n -----"
echo -e "\n $bash_script_content"
echo -e "\n -----"
