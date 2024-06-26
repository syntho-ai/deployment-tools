import os

import yaml


def replace_server_address(kubeconfig_path, new_address):
    with open(kubeconfig_path, "r") as file:
        kubeconfig = yaml.safe_load(file)

    # Replace server address in all clusters and skip TLS verify
    for cluster in kubeconfig["clusters"]:
        cluster["cluster"]["server"] = f"https://{new_address}"
        cluster["cluster"]["insecure-skip-tls-verify"] = True
        if "certificate-authority-data" in cluster["cluster"]:
            del cluster["cluster"]["certificate-authority-data"]

    with open(kubeconfig_path, "w") as file:
        yaml.safe_dump(kubeconfig, file)


def main():
    kubeconfig_path = os.getenv("KUBECONFIG", "/root/.kube/config")
    cluster_container_name = os.getenv("CLUSTER_CONTAINER_NAME")
    cluster_internal_port = os.getenv("CLUSTER_INTERNAL_PORT")
    new_address = f"{cluster_container_name}:{cluster_internal_port}"

    replace_server_address(kubeconfig_path, new_address)
    print(f"Replaced 127.0.0.1 with {new_address} and set insecure-skip-tls-verify in {kubeconfig_path}")


if __name__ == "__main__":
    main()
