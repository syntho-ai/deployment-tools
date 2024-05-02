import os
import shutil
import tarfile


def main():
    # Get the directory of the script
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Define paths relative to the script's location
    helm_dir = os.path.abspath(os.path.join(script_dir, "../../helm"))
    docker_compose_dir = os.path.abspath(os.path.join(script_dir, "../../docker-compose"))
    target_dir = os.path.abspath(os.path.join(script_dir, "scripts"))

    # Create syntho-charts directory if it doesn't exist
    syntho_charts_dir = os.path.join(target_dir, "syntho-charts")
    os.makedirs(syntho_charts_dir, exist_ok=True)

    # Delete syntho-charts.tar.gz if it exists
    syntho_charts_tar_gz = os.path.join(target_dir, "syntho-charts.tar.gz")
    if os.path.exists(syntho_charts_tar_gz):
        os.remove(syntho_charts_tar_gz)

    # Copy helm and docker-compose directories into syntho-charts directory
    shutil.copytree(helm_dir, os.path.join(syntho_charts_dir, "helm"))
    shutil.copytree(docker_compose_dir, os.path.join(syntho_charts_dir, "docker-compose"))

    # Archive syntho-charts directory into syntho-charts.tar.gz
    with tarfile.open(syntho_charts_tar_gz, "w:gz") as tar:
        tar.add(syntho_charts_dir, arcname="syntho-charts")

    # Delete syntho-charts directory
    shutil.rmtree(syntho_charts_dir)


if __name__ == "__main__":
    main()
