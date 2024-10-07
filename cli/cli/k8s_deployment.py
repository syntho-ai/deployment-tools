import os
import shutil
import time
from datetime import datetime
from enum import Enum
from hashlib import md5
from typing import Dict, List, NoReturn

import click
import yaml
from pydantic import parse_obj_as

from cli.dynamic_configuration.core import dump_envs, enrich_envs, make_envs, proceed_with_questions
from cli.dynamic_configuration.schema.question_schema import QuestionSchema
from cli.utilities.prepull_images import generate_prepull_images_dir
from cli.utils import (
    CleanUpLevel,
    DeploymentResult,
    UpdateStrategy,
    get_deployments_dir,
    get_new_release_rollout_strategy,
    run_script,
    thread_safe,
    with_working_directory,
)


class DeploymentStatus(Enum):
    INITIALIZING = ("initializing", CleanUpLevel.DIR)
    PREPARING_ENV = ("preparing-env", CleanUpLevel.DIR)
    INITIALIZED = ("initialized", CleanUpLevel.DIR)
    PRE_REQ_CHECK_IN_PROGRESS = ("pre-req-check-in-progress", CleanUpLevel.DIR)
    PRE_REQ_CHECK_SUCCEEDED = ("pre-req-check-succeeded", CleanUpLevel.DIR)
    PRE_REQ_CHECK_FAILED = ("pre-req-check-failed", CleanUpLevel.DIR)
    PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS = ("pre-deployment-operations-in-progress", CleanUpLevel.FULL)
    PRE_DEPLOYMENT_OPERATIONS_SUCCEEDED = ("pre-deployment-operations-succeeded", CleanUpLevel.FULL)
    PRE_DEPLOYMENT_OPERATIONS_FAILED = ("pre-deployment-operations-failed", CleanUpLevel.FULL)
    RAY_CLUSTER_DEPLOYMENT_IN_PROGRESS = ("ray-cluster-deployment-in-progress", CleanUpLevel.FULL)
    RAY_CLUSTER_DEPLOYMENT_SUCCEEDED = ("ray-cluster-deployment-succeeded", CleanUpLevel.FULL)
    RAY_CLUSTER_DEPLOYMENT_FAILED = ("ray-cluster-deployment-failed", CleanUpLevel.FULL)
    SYNTHO_UI_DEPLOYMENT_IN_PROGRESS = ("syntho-ui-deployment-in-progress", CleanUpLevel.FULL)
    SYNTHO_UI_DEPLOYMENT_SUCCEEDED = ("syntho-ui-deployment-succeeded", CleanUpLevel.FULL)
    SYNTHO_UI_DEPLOYMENT_FAILED = ("syntho-ui-deployment-failed", CleanUpLevel.FULL)
    COMPLETED = ("completed", CleanUpLevel.NA)

    def get(self):
        return self.value[0]

    def cleanup_level(self):
        return self.value[1]


@with_working_directory
def deployment_preparation(scripts_dir: str):
    click.echo("Step 0: Deployment Preparation;")
    run_script(scripts_dir, "", "k8s-deployment-preparation.sh")


@with_working_directory
def start(
    scripts_dir: str,
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    kubeconfig: str,
    arch_value: str,
    version: str,
    trusted_registry_image_pull_secret: str,
    skip_configuration: bool,
    use_trusted_registry: bool,
    deployment_tools_version: str,
    dry_run: bool,
) -> str:
    deployments_dir = get_deployments_dir(scripts_dir)
    deployment_id = generate_deployment_id(kubeconfig)
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

    initialize_deployment(deployment_id, deployment_dir, deployments_dir, version, use_trusted_registry)

    prepare_env(
        deployment_id,
        deployment_dir,
        deployments_dir,
        license_key,
        registry_user,
        registry_pwd,
        arch_value,
        kubeconfig,
        version,
        trusted_registry_image_pull_secret,
        skip_configuration,
        use_trusted_registry,
        deployment_tools_version,
        dry_run,
    )

    succeeded = pre_requirements_check(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre requirements check failed"),
            deployment_status=DeploymentStatus.PRE_REQ_CHECK_FAILED,
        )

    set_cluster_name(scripts_dir, deployment_id)

    succeeded = download_syntho_charts_release(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre deployment operations failed - Downloading syntho-charts release"),
            deployment_status=DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED,
        )

    succeeded = configuration_questions(
        scripts_dir,
        deployment_id,
        skip_configuration,
        version,
        license_key,
        registry_user,
        registry_pwd,
    )
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre deployment operations failed - Configuration"),
            deployment_status=DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED,
        )

    succeeded = major_predeployment_operations(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Pre deployment operations failed " "- Setting up major pre-deployment components"),
            deployment_status=DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED,
        )

    succeeded = start_deployment(scripts_dir, deployment_id)
    if not succeeded:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Syntho UI deployment failed"),
            deployment_status=DeploymentStatus.SYNTHO_UI_DEPLOYMENT_FAILED,
        )

    set_state(deployment_id, deployments_dir, DeploymentStatus.COMPLETED, is_completed=True)
    return DeploymentResult(
        succeeded=True,
        deployment_id=deployment_id,
        error=None,
        deployment_status=DeploymentStatus.COMPLETED,
    )


@thread_safe
def is_deployment_completed(deployments_dir: str, deployment_id: str) -> bool:
    deployment_state_path = f"{deployments_dir}/k8s-deployment-state.yaml"
    deployment_state_dict = None
    with open(deployment_state_path, "r") as file:
        deployment_state_dict = yaml.safe_load(file)

    deployment = next(filter(lambda d: d["id"] == deployment_id, deployment_state_dict["deployments"]), None)
    return deployment["status"] == "completed"


def cleanup(scripts_dir: str, deployment_id: str, status: DeploymentStatus) -> bool:
    click.echo(f"Deployment({deployment_id}) will be destroyed alongside its components")
    result = cleanup_with_cleanup_level(scripts_dir, deployment_id, status.cleanup_level())
    if result:
        click.echo(f"Deployment({deployment_id}) is destroyed and all its components have been removed")
    return result


def cleanup_with_cleanup_level(
    scripts_dir: str, deployment_id: str, cleanup_level: CleanUpLevel, force: bool = False
) -> bool:
    if cleanup_level == CleanUpLevel.NA:
        return

    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    if not os.path.isdir(deployment_dir):
        return

    if cleanup_level == CleanUpLevel.FULL:
        os.chdir(deployment_dir)
        result = run_script(scripts_dir, deployment_dir, "cleanup-kubernetes.sh", **{"FORCE": str(force).lower()})
        if not result.succeeded:
            return False

    time.sleep(2)
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


@with_working_directory
def destroy(scripts_dir: str, deployment_id: str, force: bool) -> bool:
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    if not os.path.isdir(deployment_dir):
        click.echo(f"Deployment({deployment_id}) couldn't be found")
        return

    click.echo(f"Deployment({deployment_id}) will be destroyed alongside its components")
    result = cleanup_with_cleanup_level(scripts_dir, deployment_id, CleanUpLevel.FULL, force=force)
    if result:
        click.echo(f"Deployment({deployment_id}) is destroyed and all its components have been removed")

    return result


def generate_deployment_id(kubeconfig: str) -> str:
    kubeconfig_content = kubeconfig
    if os.path.isfile(kubeconfig):
        with open(kubeconfig, "r") as file:
            kubeconfig_content = file.read()

    indicator_hash = md5(kubeconfig_content.encode(), usedforsecurity=False).hexdigest()
    return f"k8s-{indicator_hash}"


def get_deployment_status(deployments_dir: str, deployment_dir: str, deployment_id: str) -> DeploymentStatus:
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
    deployment_state_path = f"{deployments_dir}/k8s-deployment-state.yaml"
    if os.path.exists(deployment_state_path):
        with open(deployment_state_path, "r") as file:
            deployment_state_dict = yaml.safe_load(file)
            return deployment_state_dict

    return {
        "active_deployment_id": None,
        "deployments": [],
    }


def initialize_deployment(
    deployment_id: str, deployment_dir: str, deployments_dir: str, version: str, use_trusted_registry: bool
) -> NoReturn:
    deployments_state = get_deployments_state(deployments_dir)

    started_at = datetime.utcnow().isoformat()
    os.makedirs(deployment_dir)

    os.chdir(deployment_dir)

    deployment = {
        "id": deployment_id,
        "status": DeploymentStatus.INITIALIZING.get(),
        "initial_version": version,
        "version": version,
        "started_at": started_at,
        "finished_at": None,
        "cluster_name": None,
        "use_trusted_registry": use_trusted_registry,
    }
    deployments_state["deployments"].append(deployment)
    deployments_state["active_deployment_id"] = deployment_id

    update_deployments_state(deployments_dir, deployments_state)


@thread_safe
def update_deployments_state(deployments_dir: str, deployments_state: Dict) -> NoReturn:
    deployment_state_path = f"{deployments_dir}/k8s-deployment-state.yaml"
    with open(deployment_state_path, "w") as file:
        yaml.dump(deployments_state, file, default_flow_style=False)


def prepare_env(
    deployment_id: str,
    deployment_dir: str,
    deployments_dir: str,
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    arch_value: str,
    kubeconfig: str,
    version: str,
    trusted_registry_image_pull_secret: str,
    skip_configuration: bool,
    use_trusted_registry: bool,
    deployment_tools_version: str,
    dry_run: bool,
):
    scripts_dir = deployments_dir.replace("/deployments", "")
    set_state(deployment_id, deployments_dir, DeploymentStatus.PREPARING_ENV)

    kube_dir = f"{deployment_dir}/.kube"
    if not os.path.exists(kube_dir):
        os.makedirs(kube_dir)

    if os.path.isfile(kubeconfig):
        os.symlink(kubeconfig, f"{kube_dir}/config")
    else:
        with open(f"{kube_dir}/config", "w") as kubeconfig_file:
            kubeconfig_file.write(kubeconfig)

    kubeconfig_file_path = f"{kube_dir}/config"

    env = {
        "LICENSE_KEY": license_key,
        "REGISTRY_USER": registry_user,
        "REGISTRY_PWD": registry_pwd,
        "ARCH": arch_value,
        "KUBECONFIG": kubeconfig_file_path,
        "VERSION": version,
        "SKIP_CONFIGURATION": "true" if skip_configuration else "false",
        "USE_TRUSTED_REGISTRY": "true" if use_trusted_registry else "false",
        "PREPULL_IMAGES_DIR": generate_prepull_images_dir(scripts_dir),
        "IMAGE_PULL_SECRET": trusted_registry_image_pull_secret or "syntho-cr-secret",
        "DEPLOYMENT_TOOLS_VERSION": deployment_tools_version,
        "DRY_RUN": "true" if dry_run else "false",
    }
    env_file_path = f"{deployment_dir}/.env"
    with open(env_file_path, "w") as file:
        for key, value in env.items():
            file.write(f"{key}={value}\n")

    set_state(deployment_id, deployments_dir, DeploymentStatus.INITIALIZED)


def set_state(deployment_id: str, deployments_dir: str, status: DeploymentStatus, is_completed: bool = False):
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

    result = run_script(scripts_dir, deployment_dir, "pre-requirements-kubernetes.sh")
    if result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_REQ_CHECK_SUCCEEDED)
    else:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_REQ_CHECK_FAILED)

    return result.succeeded


def get_active_deployment_id(scripts_dir: str) -> str:
    deployments_dir = f"{scripts_dir}/deployments"
    deployments_state = get_deployments_state(deployments_dir)
    return deployments_state["active_deployment_id"]


def get_deployment(scripts_dir: str, deployment_id: str) -> Dict:
    deployments_dir = f"{scripts_dir}/deployments"
    deployments_state = get_deployments_state(deployments_dir)
    deployments = deployments_state["deployments"]
    for deployment in deployments:
        if deployment["id"] == deployment_id:
            return deployment


def get_deployments(scripts_dir: str) -> List[Dict]:
    deployments_dir = f"{scripts_dir}/deployments"
    deployments_state = get_deployments_state(deployments_dir)
    return deployments_state["deployments"]


def set_cluster_name(scripts_dir: str, deployment_id: str) -> NoReturn:
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    result = run_script(scripts_dir, deployment_dir, "get-k8s-cluster-context-name.sh", capture_output=True)
    cluster_name = result.output

    deployments_state = get_deployments_state(deployments_dir)
    for deployment in deployments_state["deployments"]:
        if deployment["id"] == deployment_id:
            deployment["cluster_name"] = cluster_name

    update_deployments_state(deployments_dir, deployments_state)


def start_deployment(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 5: Deployment;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.SYNTHO_UI_DEPLOYMENT_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "deploy-ray-and-syntho-stack.sh")
    if result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.SYNTHO_UI_DEPLOYMENT_SUCCEEDED)
    else:
        set_state(deployment_id, deployments_dir, DeploymentStatus.SYNTHO_UI_DEPLOYMENT_FAILED)

    return result.succeeded


def configuration_questions(
    scripts_dir: str,
    deployment_id: str,
    skip_configuration: bool,
    version: str,
    license_key: str,
    registry_user: str,
    registry_pwd: str,
) -> bool:
    deployment_dir = f"{scripts_dir}/deployments/{deployment_id}"
    configuration_questions_yaml_location = (
        f"{deployment_dir}/syntho-charts-{version}" "/dynamic-configuration/src/k8s_questions.yaml"
    )

    with open(configuration_questions_yaml_location, "r") as f:
        questions_config = yaml.safe_load(f)

    question_schema_obj = parse_obj_as(QuestionSchema, questions_config)
    all_envs = make_envs(question_schema_obj.envs_configuration)

    if skip_configuration:
        skipped_text = click.style("[SKIPPED]", bg="yellow", fg="white", bold=True)
        click.echo(f"Step 3: Configuration; {skipped_text}")
        default_answers = make_default_answers_when_skipped_configuration(question_schema_obj)
        all_envs[".answers.env"] = default_answers
    else:
        click.echo("Step 3: Configuration;")

        all_envs, interrupted = proceed_with_questions(
            deployment_dir, all_envs, question_schema_obj.questions, question_schema_obj.entrypoint
        )
        if interrupted:
            return False

    enrich_envs(all_envs, license_key, registry_user, registry_pwd)
    dump_envs(all_envs, deployment_dir)

    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "configuration-questions.sh")
    if not result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED)

    return result.succeeded


def make_default_answers_when_skipped_configuration(question_schema_obj):
    ### This section is for backwards-compatibility - START ###

    # below env vars are differ as their default value when they are asked vs when the conf is
    # skipped, so we are actually overriding the answers, as if the answers are like below.
    # --skip-configuration is already going to be deleted eventually, and it is meant to be for
    # experimental purposes to make the deployments faster

    # sorry for being too implicit below, but being exception free is something we don't want free
    # as we are assuming those values exist. In case they are gone, then it needs to raise an
    # exception so that we can be aware of

    resources_env_when_skipped = list(
        filter(lambda e: e.scope.value == ".resources.env", question_schema_obj.envs_configuration)
    )[0]
    config_env_when_skipped = list(
        filter(lambda e: e.scope.value == ".config.env", question_schema_obj.envs_configuration)
    )[0]

    ray_head_cpu_limit = list(filter(lambda e: e.name == "RAY_HEAD_CPU_LIMIT", resources_env_when_skipped.envs))[
        0
    ].default.replace("m", "")
    ray_head_memory_limit = list(filter(lambda e: e.name == "RAY_HEAD_MEMORY_LIMIT", resources_env_when_skipped.envs))[
        0
    ].default.replace("G", "")

    use_storage_class = "n"
    storage_class_name = list(filter(lambda e: e.name == "STORAGE_CLASS_NAME", config_env_when_skipped.envs))[0].default

    use_ingress_controller = "n"
    ingress_controller = list(filter(lambda e: e.name == "INGRESS_CONTROLLER", config_env_when_skipped.envs))[0].default

    protocol = list(filter(lambda e: e.name == "PROTOCOL", config_env_when_skipped.envs))[0].default
    tls_enabled = "n"
    overrides = {
        "RAY_HEAD_CPU_LIMIT": {"name": "RAY_HEAD_CPU_LIMIT", "value": ray_head_cpu_limit},
        "RAY_HEAD_MEMORY_LIMIT": {"name": "RAY_HEAD_MEMORY_LIMIT", "value": ray_head_memory_limit},
        "USE_STORAGE_CLASS": {"name": "USE_STORAGE_CLASS", "value": use_storage_class},
        "STORAGE_CLASS_NAME": {"name": "STORAGE_CLASS_NAME", "value": storage_class_name},
        "USE_INGRESS_CONTROLLER": {"name": "USE_INGRESS_CONTROLLER", "value": use_ingress_controller},
        "INGRESS_CONTROLLER": {"name": "INGRESS_CONTROLLER", "value": ingress_controller},
        "PROTOCOL": {"name": "PROTOCOL", "value": protocol},
        "TLS_ENABLED": {"name": "TLS_ENABLED", "value": tls_enabled},
    }

    ### This section is for backwards-compatibility - END ###

    questions = question_schema_obj.questions
    answers = []
    for question in questions:
        override = overrides.get(question.var)
        if not override:
            answers.append(
                {
                    "name": question.var,
                    "value": question.default,
                }
            )
        else:
            answers.append(override)

    return answers


def download_syntho_charts_release(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 2: Downloading the release;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "download-syntho-charts-release.sh")
    if not result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED)

    return result.succeeded


def major_predeployment_operations(scripts_dir: str, deployment_id: str) -> bool:
    click.echo("Step 4: Major pre-deployment operations;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_IN_PROGRESS)

    result = run_script(scripts_dir, deployment_dir, "major-pre-deployment-operations.sh")
    if not result.succeeded:
        set_state(deployment_id, deployments_dir, DeploymentStatus.PRE_DEPLOYMENT_OPERATIONS_FAILED)

    return result.succeeded


@with_working_directory
def update_k8s_deployment(
    scripts_dir: str,
    deployment_id: str,
    new_version: str,
) -> str:
    deployments_dir = get_deployments_dir(scripts_dir)
    deployment_dir = f"{deployments_dir}/{deployment_id}"
    deployment = get_deployment(scripts_dir, deployment_id)

    initial_version = deployment["initial_version"]
    current_version = deployment["version"]

    deployment_status = get_deployment_status(deployments_dir, deployment_dir, deployment_id)
    if deployment_status and not deployment_status.get() == DeploymentStatus.COMPLETED.get():
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=(
                "Deployment remained unfinished and " "it needs to be destroyed first. Please see syntho-cli k8s --help"
            ),
            deployment_status=None,
        )

    is_compatible = compatibility_check(scripts_dir, deployment_id, current_version, new_version)
    if not is_compatible:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=(
                "Given version and the current version are not backwards-compatible. "
                "Please reach out to support@syntho.ai for further support."
            ),
            deployment_status=None,
        )

    update_strategy = get_new_release_rollout_strategy(
        deployment_dir, initial_version, current_version, new_version, "k8s"
    )
    if update_strategy == UpdateStrategy.UNKNOWN:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Unsupported update strategy. Please reach out to support@syntho.ai for further support."),
            deployment_status=None,
        )

    is_success = update_release(
        scripts_dir, deployment_id, initial_version, current_version, new_version, update_strategy
    )

    if not is_success:
        return DeploymentResult(
            succeeded=False,
            deployment_id=deployment_id,
            error=("Updating release has been failed. Please reach out to support@syntho.ai for further support."),
            deployment_status=None,
        )

    set_version(deployment_id, deployments_dir, new_version)

    return DeploymentResult(
        succeeded=True,
        deployment_id=deployment_id,
        error=None,
        deployment_status=None,
    )


def compatibility_check(scripts_dir: str, deployment_id: str, current_version: str, new_version: str) -> bool:
    click.echo("Step 1: Further compatibility analysis is being made;")
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    result = run_script(
        scripts_dir,
        deployment_dir,
        "compatibility-check.sh",
        **{
            "DEPLOYMENT_TOOLING": "helm",
            "CONFIGURATION_QUESTIONS_PREFIX": "k8s",
            "CURRENT_VERSION": current_version,
            "NEW_VERSION": new_version,
        },
    )

    return result.succeeded


def update_release(
    scripts_dir: str,
    deployment_id: str,
    initial_version: str,
    current_version: str,
    new_version: str,
    update_strategy: UpdateStrategy,
) -> bool:
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    # initial step was 1
    step = 1

    if update_strategy == UpdateStrategy.WITH_CONFIGURATION_CHANGES:
        step += 1
        click.echo(f"Step {step}: (Changes Detected) Configuration;")
        succeeded = reask_configuration_questions(deployment_id, deployment_dir, current_version, new_version)
        if not succeeded:
            return False

    step += 1

    click.echo(f"Step {step}: Rolling out new release;")

    result = run_script(
        scripts_dir,
        deployment_dir,
        update_strategy.script(),
        **{
            "DEPLOYMENT_TOOLING": "helm",
            "CURRENT_VERSION": current_version,
            "NEW_VERSION": new_version,
            **update_strategy.extra_params(),
        },
    )

    return result.succeeded


def reask_configuration_questions(
    deployment_id: str, deployment_dir: str, current_version: str, new_version: str
) -> bool:
    previous_answers = make_previous_answers_kv_map(deployment_dir, current_version)

    new_configuration_questions_yaml_location = (
        f"{deployment_dir}/temp-compatibility-check/syntho-{new_version}/dynamic-configuration/src/k8s_questions.yaml"
    )

    with open(new_configuration_questions_yaml_location, "r") as f:
        new_questions_config = yaml.safe_load(f)

    new_question_schema_obj = parse_obj_as(QuestionSchema, new_questions_config)
    new_all_envs = make_envs(new_question_schema_obj.envs_configuration)

    new_all_envs, interrupted = proceed_with_questions(
        deployment_dir,
        new_all_envs,
        new_question_schema_obj.questions,
        new_question_schema_obj.entrypoint,
        with_previous_answers=previous_answers,
    )
    if interrupted:
        return False

    temp_deployment_dir = f"{deployment_dir}/temp-compatibility-check/syntho-{new_version}/helm/new_envs"
    os.makedirs(temp_deployment_dir, exist_ok=True)
    dump_envs(new_all_envs, temp_deployment_dir)
    return True


def make_previous_answers_kv_map(deployment_dir: str, current_version: str):
    previous_answers_env_path = f"{deployment_dir}/syntho-charts-{current_version}/helm/envs/.answers.env"
    env_var_map = {}

    with open(previous_answers_env_path, "r") as f:
        for line in f:
            line = line.strip()
            key, value = line.split("=", 1)
            env_var_map[key.strip()] = value.strip()

    return env_var_map


def set_version(deployment_id: str, deployments_dir: str, new_version: str):
    deployments_state = get_deployments_state(deployments_dir)
    for deployment in deployments_state["deployments"]:
        if deployment["id"] == deployment_id:
            deployment["version"] = new_version

    update_deployments_state(deployments_dir, deployments_state)
