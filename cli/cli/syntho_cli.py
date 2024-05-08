import importlib.metadata
import os
import sys
from typing import Optional

import click
import yaml

from cli import dc_deployment as dc_deployment_manager
from cli import k8s_deployment as k8s_deployment_manager
from cli import utils
from cli.utilities import offline_ops as offline_ops_manager
from cli.utilities import prepull_images as prepull_images_manager

syntho_cli_dir = os.path.dirname(os.path.abspath(__file__))
scripts_dir = os.path.join(syntho_cli_dir, "scripts")


def validate_kubeconfig(ctx, param, value):
    if not value:
        raise click.BadParameter("KUBECONFIG cannot be an empty string.")

    try:
        with open(value, "r") as f:
            config = yaml.safe_load(f)
    except Exception:
        try:
            config = yaml.safe_load(value)
        except Exception as exc:
            raise click.BadParameter(
                "KUBECONFIG is neither a valid YAML string nor a path to a valid YAML file."
            ) from exc

    if not isinstance(config, dict):
        raise click.BadParameter("KUBECONFIG is neither a valid YAML string nor a path to a valid YAML file.")

    # Check if the key components of the KUBECONFIG are present
    if not (config.get("clusters", False) and config.get("contexts", False) and config.get("users", False)):
        raise click.BadParameter("KUBECONFIG is not valid. It should have 'clusters', 'contexts', and 'users' fields.")

    return value


def validate_docker_config(ctx, param, value):
    if value == "":
        value = "~/.docker/config.json"
    original_docker_config_path = os.path.expanduser(value)
    if not os.path.exists(original_docker_config_path):
        if not value == "~/.docker/config.json":
            raise click.BadParameter(
                f"given docker config.json path {value} is not valid, please "
                "provide the config.json that current docker contex's "
                "daemon is using"
            )
    return value


def validate_trusted_registry(ctx, param, value):
    if value:
        prepull_images_file_dir = prepull_images_manager.generate_prepull_images_dir(scripts_dir)
        if not os.path.exists(prepull_images_file_dir):
            raise click.BadParameter(
                "syntho-cli is not ready to deploy Syntho resources from a "
                "trusted registry yet. Please run "
                "'syntho-cli utilities prepull-images --help' first "
                "for more info"
            )

        status = prepull_images_manager.get_status(scripts_dir)
        if status != "completed":
            raise click.BadParameter(
                "syntho-cli is not ready to deploy Syntho resources from a "
                "trusted registry yet. Please run "
                "'syntho-cli utilities prepull-images --help' first "
                "for more info"
            )

    return value


def validate_offline_registry(ctx, param, value):
    if value:
        offline_registry_file_dir = offline_ops_manager.generate_offline_registry_archive_path(scripts_dir)
        if not os.path.exists(offline_registry_file_dir):
            raise click.BadParameter(
                "syntho-cli is not ready to deploy Syntho resources from the "
                "offline registry yet. Please run "
                "'syntho-cli utilities activate-offline-mode --help' first "
                "for more info"
            )

        status = offline_ops_manager.get_status(scripts_dir)
        if status != "completed":
            raise click.BadParameter(
                "syntho-cli is not ready to deploy Syntho resources from the "
                "offline registry yet. Please run "
                "'syntho-cli utilities activate-offline-mode --help' first "
                "for more info"
            )

    return value


def validate_dc_deployment_id(ctx, param, value):
    if value == "":
        deployments = dc_deployment_manager.get_deployments(scripts_dir)
        if deployments:
            first_line = "--deployment-id isn't provided! Please see active deployments below.\n\n"
            second_line = yaml.dump(deployments, default_flow_style=False)
            raise click.BadParameter(first_line + second_line)
        else:
            first_line = "--deployment-id isn't provided! Also, there is currently " "no active deployment."
            raise click.BadParameter(first_line)

    return value


def validate_k8s_deployment_id(ctx, param, value):
    if value == "":
        deployments = k8s_deployment_manager.get_deployments(scripts_dir)
        if deployments:
            first_line = "--deployment-id isn't provided! Please see active deployments below.\n\n"
            second_line = yaml.dump(deployments, default_flow_style=False)
            raise click.BadParameter(first_line + second_line)
        else:
            first_line = "--deployment-id isn't provided! Also, there is currently " "no active deployment."
            raise click.BadParameter(first_line)

    return value


def validate_utility_name(ctx, param, value):
    if value == "":
        utilities = ["prepull-images", "activate-offline-mode"]
        first_line = "--utility-name isn't provided! Please see active utilities below.\n\n"
        second_line = yaml.dump(utilities, default_flow_style=False)
        raise click.BadParameter(first_line + second_line)

    return value


def validate_input_params(
    registry_user,
    registry_pwd,
    use_trusted_registry,
    use_offline_registry,
    trusted_registry_image_pull_secret=None,
    is_k8s=False,
):
    if use_trusted_registry and use_offline_registry:
        raise click.BadParameter(
            "Either provide '--use-trusted-registry' or '--use-offline-registry'. Please check:\n"
            "'syntho-cli utilities prepull-images --help'\n"
            "'syntho-cli utilities activate-offline-mode --help'"
        )

    # Verify either registry-user and registry-pwd are provided or use-trusted-registry is provided
    if not use_offline_registry:
        if (registry_user == "u" or registry_pwd == "p") and not use_trusted_registry:  # nosec
            raise click.BadParameter(
                "Either provide '--registry-user' and '--registry-pwd' or " "use '--use-trusted-registry'."
            )

    # Verify either registry-user and registry-pwd are provided or use-offline-registry is provided
    if not use_trusted_registry:
        if (registry_user == "u" or registry_pwd == "p") and not use_offline_registry:  # nosec
            raise click.BadParameter(
                "Either provide '--registry-user' and '--registry-pwd' or " "use '--use-offline-registry'."
            )

    if use_trusted_registry and is_k8s and not trusted_registry_image_pull_secret:
        raise click.BadParameter(
            "--trusted-registry-image-pull-secret should be provided " "when --use-trusted-registry is used"
        )


def get_version(package_name: str):
    try:
        version = importlib.metadata.version(package_name)
    except importlib.metadata.PackageNotFoundError:
        version = "Package not found"
    return version


@click.group()
@click.version_option(prog_name="syntho-cli", version=get_version("syntho-cli"))
def cli():
    pass


@cli.group(help="Manages Kubernetes Deployments")
def k8s():
    pass


@cli.group(help="Manages Docker Compose Deployment")
def dc():
    pass


@cli.group(help="Utilities to streamline manual operations")
def utilities():
    pass


@k8s.command(name="deployment", help="Deploys the Syntho Stack into the given cluster")
@click.option("--license-key", type=str, help="Specify the License Key that is provided by Syntho team", required=True)
@click.option(
    "--registry-user",
    type=str,
    help="Specify the docker image registry user that is provided by Syntho team",
    required=False,
    default="u",
)
@click.option(
    "--registry-pwd",
    type=str,
    help="Specify the docker image registry password that is provided by Syntho team",
    required=False,
    default="p",
)
@click.option(
    "--kubeconfig",
    type=str,
    help=(
        "Specify a kubeconfig in which the Syntho"
        " stack will be deployed into. It can be both kubeconfig content, or a file path that"
        " points to a valid kubconfig content file"
    ),
    required=True,
    callback=validate_kubeconfig,
)
@click.option(
    "--version",
    type=str,
    help=("Specify a version for Syntho stack. Default: stable"),
    default="stable",
    required=False,
)
@click.option(
    "--trusted-registry-image-pull-secret",
    type=str,
    help=('Specify an image pull secret name for trusted registry access. Default: ""'),
    default="",
    required=False,
)
@click.option(
    "--skip-configuration",
    is_flag=True,
    help="Skips configuration, and uses default configuration params for deployment",
)
@click.option(
    "--use-trusted-registry",
    is_flag=True,
    help=("Uses trusted registry instead " "- 'syntho-cli utilities prepull-images --help' for more info"),
    callback=validate_trusted_registry,
)
def k8s_deployment(
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    kubeconfig: str,
    version: Optional[str],
    trusted_registry_image_pull_secret: Optional[str],
    skip_configuration: bool,
    use_trusted_registry: bool,
):
    try:
        validate_input_params(
            registry_user,
            registry_pwd,
            use_trusted_registry,
            False,
            trusted_registry_image_pull_secret=trusted_registry_image_pull_secret,
            is_k8s=True,
        )
    except click.BadParameter as exc:
        raise click.UsageError(str(exc)) from exc

    arch = utils.get_architecture()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(f"Unsupported architecture: {arch}. Only AMD/ARM is supported.")
    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be deployed (Kubernetes) ({arch_text}) --",
        fg="white",
        blink=True,
        bold=True,
    )
    click.echo(f"{starting_text}\n")

    result = k8s_deployment_manager.start(
        scripts_dir,
        license_key,
        registry_user,
        registry_pwd,
        kubeconfig,
        arch,
        version,
        trusted_registry_image_pull_secret,
        skip_configuration,
        use_trusted_registry,
        get_version("cli"),
    )

    if result.succeeded:
        deployment_successful_text = click.style(
            "Deployment is successful. See helpful commands below.", fg="white", bold=True
        )
        deployment_status_text = click.style(
            f"Deployment status: syntho-cli k8s status --deployment-id " f"{result.deployment_id}",
            fg="white",
            bold=True,
        )
        destroy_deployment_text = click.style(
            f"Destroy deployment: syntho-cli k8s destroy " f"--deployment-id {result.deployment_id}",
            fg="white",
            bold=True,
        )
        click.echo(
            "\n" f"{deployment_successful_text}\n\n" f"{deployment_status_text}\n" f"{destroy_deployment_text}\n"
        )
    else:
        deployment_failed_text = click.style(f"Error deploying to kubernetes: {result.error}", fg="red")
        cleaningthingsup_text = click.style("Cleaning things up", fg="red")
        click.echo(f"\n\n{deployment_failed_text} - {cleaningthingsup_text}", err=True)
        is_destroyed = k8s_deployment_manager.cleanup(scripts_dir, result.deployment_id, result.deployment_status)
        if not is_destroyed:
            destroy_failed_text = click.style("Error destroying deployment\n", fg="red")
            next_command_text = click.style(
                f"Please run `syntho-cli k8s destroy --deployment-id {result.deployment_id} "
                "--force` to forcefully destroy the deployment",
                fg="red",
            )
            click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)
        sys.exit(1)


@k8s.command(name="status", help="Shows the deployment status of the given deployment")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be status checked",
    required=False,
    default="",
    callback=validate_k8s_deployment_id,
)
def k8s_deployment_status(deployment_id: str):
    deployment = k8s_deployment_manager.get_deployment(scripts_dir, deployment_id)
    if deployment:
        as_yaml = yaml.dump(deployment, default_flow_style=False)
        click.echo(as_yaml)


@k8s.command(name="destroy", help="Destroys a deployment and its components")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be destroyed",
    required=False,
    default="",
    callback=validate_k8s_deployment_id,
)
@click.option(
    "--force",
    is_flag=True,
    help="Forcefully destroys all the deployed components",
)
def k8s_deployment_destroy(deployment_id: str, force: bool):
    is_destroyed = k8s_deployment_manager.destroy(scripts_dir, deployment_id, force)
    if not is_destroyed:
        destroy_failed_text = click.style("Error destroying deployment\n", fg="red")
        next_command_text = click.style(
            f"Please run `syntho-cli k8s destroy --deployment-id {deployment_id} "
            "--force` to forcefully destroy the deployment",
            fg="red",
        )
        click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)


@k8s.command(name="deployments", help="Shows existing deployments and their statuses")
def k8s_deployments():
    deployments = k8s_deployment_manager.get_deployments(scripts_dir)
    if deployments:
        as_yaml = yaml.dump(deployments, default_flow_style=False)
        click.echo(as_yaml)
    else:
        successful_text = click.style(
            "There is no deployment yet. See helpful commands below.",
            fg="white",
            bold=True,
        )
        extra_info_text = click.style(
            "Kubernetes: syntho-cli k8s --help",
            fg="white",
            bold=True,
        )
        click.echo("\n" f"{successful_text}\n\n" f"{extra_info_text}\n")


@k8s.command(name="logs", help="Show background process logs (it can be used for troubleshooting purposes)")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id",
    required=False,
    default="",
    callback=validate_k8s_deployment_id,
)
@click.option("-n", type=int, help="Number of lines. Default: 1000", required=False, default=1000)
@click.option("-f", is_flag=True, help="Follow the process's logs")
def k8s_logs(deployment_id: str, n: int, f: bool):
    # function body here
    exists = utils.deployment_exists(scripts_dir, deployment_id)
    if not exists:
        not_found_text = click.style(f"Deployment ({deployment_id}) couldn't not be found\n", fg="red")
        click.echo(f"\n\n{not_found_text}", err=True)
        return

    utils.logs(scripts_dir, deployment_id, n, f)


@dc.command(name="deployment", help="Deploys the Syntho Stack into the given host's docker environment")
@click.option("--license-key", type=str, help="Specify the License Key that is provided by Syntho team", required=True)
@click.option(
    "--registry-user",
    type=str,
    help="Specify the docker image registry user that is provided by Syntho team",
    required=False,
    default="u",
)
@click.option(
    "--registry-pwd",
    type=str,
    help="Specify the docker image registry password that is provided by Syntho team",
    required=False,
    default="p",
)
@click.option(
    "--docker-host",
    type=str,
    help="Specify the docker host. Default: unix:///var/run/docker.sock",
    default="unix:///var/run/docker.sock",
    required=False,
)
@click.option(
    "--docker-ssh-user-private-key",
    type=str,
    help="Specify a private key for remote docker host access via ssh. Default: null",
    default=None,
    required=False,
)
@click.option("--version", type=str, help=("Specify a version for Syntho stack."), required=True)
@click.option(
    "--docker-config",
    type=str,
    help=("Specify the default docker config.json path. Default: ~/.docker/config.json"),
    default="",
    required=False,
    callback=validate_docker_config,
)
@click.option(
    "--skip-configuration",
    is_flag=True,
    help="Skips configuration, and uses default configuration params for deployment",
)
@click.option(
    "--use-trusted-registry",
    is_flag=True,
    help=("Uses trusted registry instead " "- 'syntho-cli utilities prepull-images --help' for more info"),
    callback=validate_trusted_registry,
)
@click.option(
    "--use-offline-registry",
    is_flag=True,
    help=("Uses offline registry instead " "- 'syntho-cli utilities activate-offline-mode --help' for more info"),
    callback=validate_offline_registry,
)
def dc_deployment(
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    docker_host: str,
    docker_ssh_user_private_key: str,
    version: Optional[str],
    docker_config: str,
    skip_configuration: bool,
    use_trusted_registry: bool,
    use_offline_registry: bool,
):
    try:
        validate_input_params(
            registry_user,
            registry_pwd,
            use_trusted_registry,
            use_offline_registry,
            trusted_registry_image_pull_secret=None,
            is_k8s=False,
        )
    except click.BadParameter as exc:
        raise click.UsageError(str(exc)) from exc

    arch = utils.get_architecture()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(f"Unsupported architecture: {arch}. Only AMD/ARM is supported.")
    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be deployed (Docker Compose) ({arch_text}) --",
        fg="white",
        blink=True,
        bold=True,
    )
    click.echo(f"{starting_text}\n")

    result = dc_deployment_manager.start(
        scripts_dir,
        license_key,
        registry_user,
        registry_pwd,
        docker_host,
        docker_ssh_user_private_key,
        arch,
        version,
        docker_config,
        skip_configuration,
        use_trusted_registry,
        use_offline_registry,
        get_version("cli"),
    )

    if result.succeeded:
        deployment_successful_text = click.style(
            "Deployment is successful. See helpful commands below.", fg="white", bold=True
        )
        deployment_status_text = click.style(
            f"Deployment status: syntho-cli dc status --deployment-id " f"{result.deployment_id}",
            fg="white",
            bold=True,
        )
        destroy_deployment_text = click.style(
            f"Destroy deployment: syntho-cli dc destroy " f"--deployment-id {result.deployment_id}",
            fg="white",
            bold=True,
        )
        click.echo(
            "\n" f"{deployment_successful_text}\n\n" f"{deployment_status_text}\n" f"{destroy_deployment_text}\n"
        )
    else:
        deployment_failed_text = click.style(f"Error deploying to docker compose: {result.error}", fg="red")
        cleaningthingsup_text = click.style("Cleaning things up", fg="red")
        click.echo(f"\n\n{deployment_failed_text} - {cleaningthingsup_text}", err=True)
        is_destroyed = dc_deployment_manager.cleanup(scripts_dir, result.deployment_id, result.deployment_status)
        if not is_destroyed:
            destroy_failed_text = click.style("Error destroying deployment\n", fg="red")
            next_command_text = click.style(
                f"Please run `syntho-cli dc destroy --deployment-id {result.deployment_id} "
                "--force` to forcefully destroy the deployment",
                fg="red",
            )
            click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)
        sys.exit(1)


@dc.command(name="status", help="Shows the deployment status of the given deployment")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be status checked",
    required=False,
    default="",
    callback=validate_dc_deployment_id,
)
def dc_deployment_status(deployment_id: str):
    deployment = dc_deployment_manager.get_deployment(scripts_dir, deployment_id)
    if deployment:
        as_yaml = yaml.dump(deployment, default_flow_style=False)
        click.echo(as_yaml)


@dc.command(name="destroy", help="Destroys a deployment and its components")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be destroyed",
    required=False,
    default="",
    callback=validate_dc_deployment_id,
)
@click.option(
    "--force",
    is_flag=True,
    help="Forcefully destroys all the deployed components",
)
def dc_deployment_destroy(deployment_id: str, force: bool):
    is_destroyed = dc_deployment_manager.destroy(scripts_dir, deployment_id, force)
    if not is_destroyed:
        destroy_failed_text = click.style("Error destroying deployment\n", fg="red")
        next_command_text = click.style(
            f"Please run `syntho-cli dc destroy --deployment-id {deployment_id} "
            "--force` to forcefully destroy the deployment",
            fg="red",
        )
        click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)


@dc.command(name="deployments", help="Shows existing deployments and their statuses")
def dc_deployments():
    deployments = dc_deployment_manager.get_deployments(scripts_dir)
    if deployments:
        as_yaml = yaml.dump(deployments, default_flow_style=False)
        click.echo(as_yaml)
    else:
        successful_text = click.style(
            "There is no deployment yet. See helpful commands below.",
            fg="white",
            bold=True,
        )
        extra_info_text = click.style(
            "Docker compose: syntho-cli dc --help",
            fg="white",
            bold=True,
        )
        click.echo("\n" f"{successful_text}\n\n" f"{extra_info_text}\n")


@dc.command(name="logs", help="Show background process logs (it can be used for troubleshooting purposes)")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id",
    required=False,
    default="",
    callback=validate_dc_deployment_id,
)
@click.option("-n", type=int, help="Number of lines. Default: 1000", required=False, default=1000)
@click.option("-f", is_flag=True, help="Follow the process's logs")
def dc_logs(deployment_id: str, n: int, f: bool):
    # function body here
    exists = utils.deployment_exists(scripts_dir, deployment_id)
    if not exists:
        not_found_text = click.style(f"Deployment ({deployment_id}) couldn't not be found\n", fg="red")
        click.echo(f"\n\n{not_found_text}", err=True)
        return

    utils.logs(scripts_dir, deployment_id, n, f)


@utilities.command(name="prepull-images", help="Pulls Syntho's images into a trusted registry")
@click.option("--trusted-registry", type=str, help="Specify the registry for images to be pulled into", required=True)
@click.option(
    "--syntho-registry-user",
    type=str,
    help="Specify the Syntho docker image registry user that is provided by Syntho team",
    required=True,
)
@click.option(
    "--syntho-registry-pwd",
    type=str,
    help="Specify the Syntho docker image registry password that is provided by Syntho team",
    required=True,
)
@click.option("--version", type=str, help=("Specify a version for Syntho stack."), required=True)
@click.option(
    "--docker-config",
    type=str,
    help=("Specify the default docker config.json path. Default: ~/.docker/config.json"),
    default="",
    required=False,
    callback=validate_docker_config,
)
def prepull_images(
    trusted_registry: str, syntho_registry_user: str, syntho_registry_pwd: str, version: str, docker_config: str
):
    arch = utils.get_architecture()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(f"Unsupported architecture: {arch}. Only AMD/ARM is supported.")

    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be pulling images into a trusted registry ({arch_text}) --",
        fg="white",
        blink=True,
        bold=True,
    )
    click.echo(f"{starting_text}\n")

    result, err = prepull_images_manager.start(
        scripts_dir,
        version,
        arch,
        trusted_registry,
        syntho_registry_user,
        syntho_registry_pwd,
        docker_config,
    )
    if not result:
        pull_failed_text = click.style(f"Error pulling images. Error: {err}\n", fg="red")
        click.echo(f"\n\n{pull_failed_text}", err=True)
    else:
        successful_text = click.style(
            "Images have been pulled into the given trusted registry. See helpful commands below.",
            fg="white",
            bold=True,
        )
        extra_info_text1 = click.style(
            "Kubernetes deployment from a trusted registry: syntho-cli k8s deployment --help",
            fg="white",
            bold=True,
        )
        extra_info_text2 = click.style(
            "Docker compose deployment from a trusted registry: syntho-cli dc deployment --help",
            fg="white",
            bold=True,
        )
        click.echo("\n" f"{successful_text}\n\n" f"{extra_info_text1}\n" f"{extra_info_text2}\n")


@utilities.command(
    name="activate-offline-mode",
    help=(
        "Activates CLI to make deployments to (later) offline ecosystems. "
        "eg. a docker host with no outbound internet access"
    ),
)
@click.option(
    "--syntho-registry-user",
    type=str,
    help="Specify the Syntho docker image registry user that is provided by Syntho team",
    required=True,
)
@click.option(
    "--syntho-registry-pwd",
    type=str,
    help="Specify the Syntho docker image registry password that is provided by Syntho team",
    required=True,
)
@click.option("--version", type=str, help=("Specify a version for Syntho stack."), required=True)
@click.option(
    "--docker-config",
    type=str,
    help=("Specify the default docker config.json path. Default: ~/.docker/config.json"),
    default="",
    required=False,
    callback=validate_docker_config,
)
def activate_offline_mode(syntho_registry_user: str, syntho_registry_pwd: str, version: str, docker_config: str):
    arch = utils.get_architecture()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(f"Unsupported architecture: {arch}. Only AMD/ARM is supported.")

    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be activating offline mode ({arch_text}) --",
        fg="white",
        blink=True,
        bold=True,
    )
    click.echo(f"{starting_text}\n")

    result, err = offline_ops_manager.create_offline_registry(
        scripts_dir,
        version,
        arch,
        syntho_registry_user,
        syntho_registry_pwd,
        docker_config,
    )
    if not result:
        failed_text = click.style(f"Error activating offline mode. Error: {err}\n", fg="red")
        click.echo(f"\n\n{failed_text}", err=True)
    else:
        successful_text = click.style(
            "Offline registry has been prepared and now it can be deployed to a docker host that "
            "doesn't have an active internet connection. See helpful commands below.",
            fg="white",
            bold=True,
        )
        extra_info_text1 = click.style(
            "Docker compose deployment from an offline registry: syntho-cli dc deployment --help",
            fg="white",
            bold=True,
        )
        click.echo("\n" f"{successful_text}\n\n" f"{extra_info_text1}\n")


@utilities.command(name="logs", help="Show background process logs (it can be used for troubleshooting purposes)")
@click.option(
    "--utility-name",
    type=str,
    help="Specify the utility name. Eg. prepull-images",
    required=False,
    default="",
    callback=validate_utility_name,
)
@click.option("-n", type=int, help="Number of lines. Default: 1000", required=False, default=1000)
@click.option("-f", is_flag=True, help="Follow the process's logs")
def utility_logs(utility_name: str, n: int, f: bool):
    exists = utils.utility_exists(scripts_dir, utility_name)
    if not exists:
        not_found_text = click.style(f"Active or existing process ({utility_name}) couldn't not be found\n", fg="red")
        click.echo(f"\n\n{not_found_text}", err=True)
        return

    utils.logs(scripts_dir, utility_name, n, f, is_deployment=False)


if __name__ == "__main__":
    cli()
