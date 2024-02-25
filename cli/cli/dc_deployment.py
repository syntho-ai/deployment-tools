import os
import shutil
import yaml
import base64
import click
import json

from typing import Dict, NoReturn, List
from hashlib import md5
from datetime import datetime
from enum import Enum


from cli.utils import (thread_safe, with_working_directory, DeploymentResult,
                       get_deployments_dir, CleanUpLevel, run_script)
from cli.utilities.prepull_images import generate_prepull_images_dir


class DeploymentStatus(Enum):
    INITIALIZING = ("initializing", CleanUpLevel.DIR)
    PREPARING_ENV = ("preparing-env", CleanUpLevel.DIR)
    INITIALIZED = ("initialized", CleanUpLevel.DIR)
    PRE_REQ_CHECK_IN_PROGRESS = ("pre-req-check-in-progress", CleanUpLevel.DIR)
    PRE_REQ_CHECK_SUCCEEDED = ("pre-req-check-succeeded", CleanUpLevel.DIR)
    PRE_REQ_CHECK_FAILED = ("pre-req-check-failed", CleanUpLevel.DIR)
    PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS = ("pre-deployment-operations-in-progress",
                                             CleanUpLevel.FULL)
    PRE_DEPLOYMENT_OPERATIONS_SUCCEEDED = ("pre-deployment-operations-succeeded",
                                           CleanUpLevel.FULL)
    PRE_DEPLOYMENT_OPERATIONS_FAILED = ("pre-deployment-operations-failed", CleanUpLevel.FULL)
    DEPLOYMENT_IN_PROGRESS = ("deployment-in-progress", CleanUpLevel.FULL)
    DEPLOYMENT_SUCCEEDED = ("deployment-succeeded", CleanUpLevel.FULL)
    DEPLOYMENT_FAILED = ("deployment-failed", CleanUpLevel.FULL)
    COMPLETED = ("completed", CleanUpLevel.NA)

    def get(self):
        return self.value[0]

    def cleanup_level(self):
        return self.value[1]


@with_working_directory
def start(scripts_dir: str,
          license_key: str,
          registry_user: str,
          registry_pwd: str,
          docker_host,
          docker_ssh_user_private_key,
          arch_value: str,
          version: str,
          docker_config_json_path: str,
          skip_configuration: bool,
          use_trusted_registry: bool) -> str:


    deployments_dir = get_deployments_dir(scripts_dir)
    deployment_id = generate_deployment_id(docker_host)
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    deployment_status = get_deployment_status(deployments_dir, deployment_dir, deployment_id)
    if deployment_status:
        if deployment_status.get() == DeploymentStatus.COMPLETED.get():
            return DeploymentResult(
                succeeded=True,
                deployment_id=deployment_id,
                error=None,
                deployment_status=deployment_status,
            )
        else:
            return DeploymentResult(
                succeeded=False,
                deployment_id=deployment_id,
                error=("Deployment remained unfinished"),
                deployment_status=deployment_status,
            )

    initialize_deployment(deployment_id, deployment_dir, deployments_dir, version, docker_host)

    prepare_env(
        deployment_id,
        deployment_dir,
        deployments_dir,
        license_key,
        registry_user,
        registry_pwd,
        docker_host,
        docker_ssh_user_private_key,
        arch_value,
        version,
        docker_config_json_path,
        skip_configuration,
        use_trusted_registry,
    )

    succeeded = pre_requirements_check(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre requirements check failed"),
            deployment_status=DeploymentStatus.PRE_REQ_CHECK_FAILED,
        )

    succeeded = configuration_questions(scripts_dir, deployment_id, skip_configuration)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre deployment operations failed - Configuration"),
            deployment_status=DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED,
        )

    succeeded = download_syntho_charts_release(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre deployment operations failed - Downloading syntho-charts release"),
            deployment_status=DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED,
        )

    succeeded = start_deployment(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Syntho UI deployment failed"),
            deployment_status=DeploymentStatus.DEPLOYMENT_FAILED,
        )

    set_state(deployment_id, deployments_dir, DeploymentStatus.COMPLETED, is_completed=True)
    return DeploymentResult(
        succeeded=True,
        deployment_id=deployment_id,
        error=None,
        deployment_status=DeploymentStatus.COMPLETED,
    )

def generate_deployment_id(docker_host: str) -> str:
    deployment_indicator = f"host:{docker_host}"
    indicator_hash = md5(deployment_indicator.encode()).hexdigest()
    return f"dc-{indicator_hash}"


def get_deployment_status(deployments_dir: str,
                          deployment_dir: str,
                          deployment_id: str) -> DeploymentStatus:
    exists = os.path.exists(deployment_dir)
    if not exists:
        return None

    deployments_state = get_deployments_state(deployments_dir)
    filtered = list(filter(lambda d: d["id"] == deployment_id, deployments_state["deployments"]))
    deployment = filtered[0]

    for deployment_status in DeploymentStatus:
        if deployment_status.get() == deployment["status"]:
            return deployment_status


@thread_safe
def get_deployments_state(deployments_dir: str) -> Dict:
    deployment_state_path = f"{deployments_dir}/dc-deployment-state.yaml"
    if os.path.exists(deployment_state_path):
        with open(deployment_state_path, "r") as file:
            deployment_state_dict = yaml.safe_load(file)
            return deployment_state_dict

    return {
        "active_deployment_id": None,
        "deployments": [],
    }


def cleanup(scripts_dir: str, deployment_id: str, status: DeploymentStatus) -> bool:
    click.echo(f"Deployment({deployment_id}) will be destroyed alongside its components")
    result = cleanup_with_cleanup_level(scripts_dir, deployment_id, status.cleanup_level())
    if result:
        click.echo(
            f"Deployment({deployment_id}) is destroyed and all its components have been removed"
        )
    return result


def cleanup_with_cleanup_level(scripts_dir: str, deployment_id: str, cleanup_level: CleanUpLevel,
                               force: bool = False) -> bool:
    if cleanup_level == CleanUpLevel.NA:
        return

    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    if not os.path.isdir(deployment_dir):
        return

    if cleanup_level == CleanUpLevel.FULL:
        os.chdir(deployment_dir)
        result = run_script(
            scripts_dir,
            deployment_dir,
            "cleanup-docker-compose.sh",
            **{"FORCE": str(force).lower()}
        )
        if not result.succeeded:
            return False

    shutil.rmtree(deployment_dir)

    deployments_state = get_deployments_state(deployments_dir)
    deployments_state["active_deployment_id"] = None

    deployments = deployments_state["deployments"]
    _deployments = []
    for deployment in deployments:
        if deployment["id"] == deployment_id:
            continue

        _deployments.append(deployment)

    deployments_state["deployments"] = _deployments
    if _deployments:
        deployments_state["active_deployment_id"] = _deployments[-1]["id"]
    update_deployments_state(deployments_dir, deployments_state)
    return True


@thread_safe
def update_deployments_state(deployments_dir: str, deployments_state: Dict) -> NoReturn:
    deployment_state_path = f"{deployments_dir}/dc-deployment-state.yaml"
    with open(deployment_state_path, "w") as file:
        yaml.dump(deployments_state, file, default_flow_style=False)


def initialize_deployment(deployment_id: str,
                          deployment_dir: str,
                          deployments_dir: str,
                          version: str,
                          host_name: str) -> NoReturn:

    deployments_state = get_deployments_state(deployments_dir)

    started_at = datetime.utcnow().isoformat()
    os.makedirs(deployment_dir)

    os.chdir(deployment_dir)

    deployment = {
        "id": deployment_id,
        "status": DeploymentStatus.INITIALIZING.get(),
        "version": version,
        "started_at": started_at,
        "finished_at": None,
        "host_name": host_name,
    }
    deployments_state["deployments"].append(deployment)
    deployments_state["active_deployment_id"] = deployment_id

    update_deployments_state(deployments_dir, deployments_state)


def get_deployment(scripts_dir: str, deployment_id: str) -> Dict:
    deployments_dir = f"{scripts_dir}/deployments"
    deployments_state = get_deployments_state(deployments_dir)
    deployments = deployments_state["deployments"]
    for deployment in deployments:
        if deployment["id"] == deployment_id:
            return deployment


@with_working_directory
def destroy(scripts_dir: str, deployment_id: str, force: bool) -> bool:
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    if not os.path.isdir(deployment_dir):
        click.echo(f"Deployment({deployment_id}) couldn't be found")
        return True

    click.echo(f"Deployment({deployment_id}) will be destroyed alongside its components")
    result = cleanup_with_cleanup_level(scripts_dir, deployment_id, CleanUpLevel.FULL, force=force)
    if result:
        click.echo(
            f"Deployment({deployment_id}) is destroyed and all its components have been removed"
        )

    return result


def get_deployments(scripts_dir: str) -> List[Dict]:
    deployments_dir = f"{scripts_dir}/deployments"
    deployments_state = get_deployments_state(deployments_dir)
    return deployments_state["deployments"]


def prepare_env(deployment_id: str,
                deployment_dir: str,
                deployments_dir: str,
                license_key: str,
                registry_user: str,
                registry_pwd: str,
                docker_host: str,
                docker_ssh_user_private_key: str,
                arch_value: str,
                version: str,
                docker_config_json_path: str,
                skip_configuration: bool,
                use_trusted_registry: bool):

    scripts_dir = deployments_dir.replace("/deployments", "")
    set_state(deployment_id, deployments_dir, DeploymentStatus.PREPARING_ENV)


    base64_registry_creds = base64.b64encode(
        f"{registry_user}:{registry_pwd}".encode()
    ).decode()

    secondary_docker_config = {}
    docker_config_json_path = os.path.expanduser(docker_config_json_path)

    if os.path.exists(docker_config_json_path):
        with open(docker_config_json_path, "r") as file:
            try:
                config_data = json.load(file)
                creds_store = config_data.get("credsStore")
                cred_helpers = config_data.get("credHelpers")
                auths = config_data.get("auths")
                if creds_store:
                    secondary_docker_config = {
                        "auths": {
                            "https://index.docker.io/v1/": {},
                        },
                        "credsStore": creds_store
                    }
                if cred_helpers:
                    secondary_docker_config.update({"credHelpers": cred_helpers})
                if auths:
                    secondary_docker_config["auths"].update(auths)

            except ValueError:
                pass

    docker_config = {
        "auths": {
            "syntho.azurecr.io": {
                "auth": base64_registry_creds
            }
        }
    }

    docker_dir = f"{deployment_dir}/.docker"
    if not os.path.exists(docker_dir):
        os.makedirs(docker_dir)

    docker_config_json = json.dumps(docker_config, indent=2)
    docker_config_file_path = f"{docker_dir}/config.json"

    with open(docker_config_file_path, "w") as docker_config_file:
        docker_config_file.write(docker_config_json)

    secondary_docker_config_file_path = docker_config_file_path
    if secondary_docker_config:
        secondary_docker_dir = f"{deployment_dir}/.docker-secondary"
        if not os.path.exists(secondary_docker_dir):
            os.makedirs(secondary_docker_dir)

        secondary_docker_config_json = json.dumps(secondary_docker_config, indent=2)
        secondary_docker_config_file_path = f"{secondary_docker_dir}/config.json"

        with open(secondary_docker_config_file_path, "w") as secondary_docker_config_file:
            secondary_docker_config_file.write(secondary_docker_config_json)

    env = {
        "LICENSE_KEY": license_key,
        "REGISTRY_USER": registry_user,
        "REGISTRY_PWD": registry_pwd,
        "ARCH": arch_value,
        "DOCKER_CONFIG": docker_config_file_path.replace("/config.json", ""),
        "SECONDARY_DOCKER_CONFIG": secondary_docker_config_file_path.replace("/config.json", ""),
        "DOCKER_HOST": docker_host,
        "DOCKER_SSH_USER_PRIVATE_KEY": docker_ssh_user_private_key,
        "VERSION": version,
        "SKIP_CONFIGURATION": "true" if skip_configuration else "false",
        "USE_TRUSTED_REGISTRY": "true" if use_trusted_registry else "false",
        "PREPULL_IMAGES_DIR": generate_prepull_images_dir(scripts_dir),
    }
    env_file_path = f"{deployment_dir}/.env"
    with open(env_file_path, "w") as file:
        for key, value in env.items():
            if value:
                file.write(f"{key}={value}\n")
            else:
                file.write(f"{key}=\n")

    set_state(deployment_id, deployments_dir, DeploymentStatus.INITIALIZED)


def set_state(deployment_id: str,
              deployments_dir: str,
              status: DeploymentStatus,
              is_completed: bool = False):
    deployments_state = get_deployments_state(deployments_dir)
    for deployment in deployments_state["deployments"]:
        if deployment["id"] == deployment_id:
            deployment["status"] = status.get()
            if is_completed:
                finished_at = datetime.utcnow().isoformat()
                deployment["finished_at"] = finished_at

    update_deployments_state(deployments_dir, deployments_state)


def pre_requirements_check(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 1: Pre-requirement check;")

    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_REQ_CHECK_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "pre-requirements-dc.sh")
    if result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_REQ_CHECK_SUCCEEDED)
    else:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_REQ_CHECK_FAILED)

    return result.succeeded


def configuration_questions(scripts_dir: str, deployment_id: str, skip_configuration) -> bool:
    if not skip_configuration:
        click.echo("Step 2: Configuration;")
    else:
        skipped_text = click.style("[SKIPPED]", bg="yellow", fg="white", bold=True)
        click.echo(f"Step 2: Configuration; {skipped_text}")

    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "configuration-questions-dc.sh")
    if not result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED)

    return result.succeeded


def download_syntho_charts_release(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 3: Downloading the release;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "download-syntho-charts-release-dc.sh")
    if not result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED)

    if result.succeeded:
        set_state(
            deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_SUCCEEDED
        )

    return result.succeeded


def start_deployment(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 4: Deployment;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.DEPLOYMENT_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "deploy-ray-and-syntho-stack-dc.sh")
    if result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.DEPLOYMENT_SUCCEEDED)
    else:
        set_state(deployment_id, deployments_dir, DeploymentStatus.DEPLOYMENT_FAILED)

    return result.succeeded
