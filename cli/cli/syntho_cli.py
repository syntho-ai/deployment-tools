import sys
import os
import click
import yaml
from typing import Optional


from cli import utils
from cli import k8s_deployment as k8s_deployment_manager
from cli import dc_deployment as dc_deployment_manager
from cli.utilities import prepull_images as prepull_images_manager


syntho_cli_dir = os.path.dirname(os.path.abspath(__file__))
scripts_dir = os.path.join(syntho_cli_dir, "scripts")


def validate_kubeconfig(ctx, param, value):
    if not value:
        raise click.BadParameter("KUBECONFIG cannot be an empty string.")

    try:
        with open(value, "r") as f:
            config = yaml.safe_load(f)
    except Exception as e:
        try:
            config = yaml.safe_load(value)
        except Exception as e:
            raise click.BadParameter("KUBECONFIG is neither a valid YAML string nor a path to a valid YAML file.")

    if not isinstance(config, dict):
        raise click.BadParameter("KUBECONFIG is neither a valid YAML string nor a path to a valid YAML file.")

    # Check if the key components of the KUBECONFIG are present
    if not (config.get('clusters', False) and config.get('contexts', False) and config.get('users', False)):
        raise click.BadParameter("KUBECONFIG is not valid. It should have 'clusters', 'contexts', and 'users' fields.")

    return value


def validate_docker_config(ctx, param, value):
    if value == "":
        value = "~/.docker/config.json"
    original_docker_config_path = os.path.expanduser(value)
    if not os.path.exists(original_docker_config_path):
        if not value == "~/.docker/config.json":
            raise click.BadParameter(f"given docker config.json path {value} is not valid, please "
                                     "provide the config.json that current docker contex's "
                                     "daemon is using")
    return value


@click.group()
@click.version_option(prog_name="syntho-cli", version="0.1.0")
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


# @k8s.command(name="preparation", help="Helps to prepare kubeconfig before proceeding with a deployment")
# def k8s_preparation():
#     k8s_deployment_manager.deployment_preparation(scripts_dir)


@k8s.command(name="deployment", help="Deploys the Syntho Stack into the given cluster")
@click.option(
    "--license-key",
    type=str,
    help="Specify the License Key that is provided by Syntho team",
    required=True
)
@click.option(
    "--registry-user",
    type=str,
    help="Specify the docker image registry user that is provided by Syntho team",
    required=True
)
@click.option(
    "--registry-pwd",
    type=str,
    help="Specify the docker image registry password that is provided by Syntho team",
    required=True
)
@click.option(
    "--kubeconfig",
    type=str,
    help=("Specify a kubeconfig in which the Syntho"
          " stack will be deployed into. It can be both kubeconfig content, or a file path that"
          " points to a valid kubconfig content file"),
    required=True,
    callback=validate_kubeconfig
)
@click.option(
    "--arch",
    type=str,
    help=("Specify the architecture. Default: amd"),
    default="amd",
    required=False
)
@click.option(
    "--version",
    type=str,
    help=("Specify a version for Syntho stack. Default: stable"),
    default="stable",
    required=False
)
@click.option(
    "--skip-configuration",
    is_flag=True,
    help="Skip configuration, and use default configuration params for deployment",
)
def k8s_deployment(
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    kubeconfig: str,
    arch: str,
    version: Optional[str],
    skip_configuration: bool,
):
    arch = arch.lower()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(
            f"Unsupported architecture: {arch}. Only AMD/ARM is supported."
        )
    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be deployed (Kubernetes) ({arch_text}) --", fg="white", blink=True, bold=True,
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
        skip_configuration,
    )

    if result.succeeded:
        deployment_successful_text = click.style(
            "Deployment is successful. See helpful commands below.", fg="white", bold=True
        )
        deployment_status_text = click.style(
            f"Deployment status: syntho-cli k8s status --deployment-id "
            f"{result.deployment_id}",
            fg="white",
            bold=True,
        )
        destroy_deployment_text = click.style(
            f"Destroy deployment: syntho-cli k8s destroy "
            f"--deployment-id {result.deployment_id}",
            fg="white",
            bold=True,
        )
        click.echo(
            "\n"
            f"{deployment_successful_text}\n\n"
            f"{deployment_status_text}\n"
            f"{destroy_deployment_text}\n"
        )
    else:
        deployment_failed_text = click.style(
            f"Error deploying to kubernetes: {result.error}", fg="red"
        )
        cleaningthingsup_text = click.style(
            "Cleaning things up", fg="red"
        )
        click.echo(f"\n\n{deployment_failed_text} - {cleaningthingsup_text}", err=True)
        is_destroyed = k8s_deployment_manager.cleanup(scripts_dir, result.deployment_id, result.deployment_status)
        if not is_destroyed:
            destroy_failed_text = click.style(
                f"Error destroying deployment\n", fg="red"
            )
            next_command_text = click.style(
                f"Please run `syntho-cli k8s destroy --deployment-id {result.deployment_id} "
                "--force` to forcefully destroy the deployment", fg="red"
            )
            click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)
        sys.exit(1)


@k8s.command(name="status", help="Shows the deployment status of the given deployment")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be status checked",
    required=True
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
    required=True
)
@click.option(
    "--force",
    is_flag=True,
    help="Forcefully destroys all the deployed components",
)
def k8s_deployment_destroy(deployment_id: str, force: bool):
    is_destroyed = k8s_deployment_manager.destroy(scripts_dir, deployment_id, force)
    if not is_destroyed:
        destroy_failed_text = click.style(
            f"Error destroying deployment\n", fg="red"
        )
        next_command_text = click.style(
            f"Please run `syntho-cli k8s destroy --deployment-id {deployment_id} "
            "--force` to forcefully destroy the deployment", fg="red"
        )
        click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)



@k8s.command(name="deployments", help="Shows existing deployments and their statuses")
def k8s_deployments():
    deployments = k8s_deployment_manager.get_deployments(scripts_dir)
    as_yaml = yaml.dump(deployments, default_flow_style=False)
    click.echo(as_yaml)


@dc.command(name="deployment", help="Deploys the Syntho Stack into the given host's docker environment")
@click.option(
    "--license-key",
    type=str,
    help="Specify the License Key that is provided by Syntho team",
    required=True
)
@click.option(
    "--registry-user",
    type=str,
    help="Specify the docker image registry user that is provided by Syntho team",
    required=True
)
@click.option(
    "--registry-pwd",
    type=str,
    help="Specify the docker image registry password that is provided by Syntho team",
    required=True
)
@click.option(
    "--docker-host",
    type=str,
    help="Specify the docker host. Default: unix:///var/run/docker.sock",
    default="unix:///var/run/docker.sock",
    required=False
)
@click.option(
    "--docker-ssh-user-private-key",
    type=str,
    help="Specify a private key for remote docker host access via ssh. Default: null",
    default=None,
    required=False
)
@click.option(
    "--arch",
    type=str,
    help=("Specify the architecture. Default: amd"),
    default="amd",
    required=False
)
@click.option(
    "--version",
    type=str,
    help=("Specify a version for Syntho stack."),
    required=True
)
@click.option(
    "--docker-config",
    type=str,
    help=("Specify the default docker config.json path. Default: ~/.docker/config.json"),
    default="",
    required=False,
    callback=validate_docker_config
)
@click.option(
    "--skip-configuration",
    is_flag=True,
    help="Skip configuration, and use default configuration params for deployment",
)
def dc_deployment(
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    docker_host: str,
    docker_ssh_user_private_key: str,
    arch: Optional[str],
    version: Optional[str],
    docker_config: str,
    skip_configuration: bool,
):
    arch = arch.lower()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(
            f"Unsupported architecture: {arch}. Only AMD/ARM is supported."
        )
    arch_text = f"Architecture: {arch}64"
    if arch == "arm":
        arch_text += " - Beta"

    starting_text = click.style(
        f"-- Syntho stack is going to be deployed (Docker Compose) ({arch_text}) --", fg="white", blink=True, bold=True,
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
    )

    if result.succeeded:
        deployment_successful_text = click.style(
            "Deployment is successful. See helpful commands below.", fg="white", bold=True
        )
        deployment_status_text = click.style(
            f"Deployment status: syntho-cli dc status --deployment-id "
            f"{result.deployment_id}",
            fg="white",
            bold=True,
        )
        destroy_deployment_text = click.style(
            f"Destroy deployment: syntho-cli dc destroy "
            f"--deployment-id {result.deployment_id}",
            fg="white",
            bold=True,
        )
        click.echo(
            "\n"
            f"{deployment_successful_text}\n\n"
            f"{deployment_status_text}\n"
            f"{destroy_deployment_text}\n"
        )
    else:
        deployment_failed_text = click.style(
            f"Error deploying to docker compose: {result.error}", fg="red"
        )
        cleaningthingsup_text = click.style(
            "Cleaning things up", fg="red"
        )
        click.echo(f"\n\n{deployment_failed_text} - {cleaningthingsup_text}", err=True)
        is_destroyed = dc_deployment_manager.cleanup(scripts_dir, result.deployment_id, result.deployment_status)
        if not is_destroyed:
            destroy_failed_text = click.style(
                f"Error destroying deployment\n", fg="red"
            )
            next_command_text = click.style(
                f"Please run `syntho-cli dc destroy --deployment-id {result.deployment_id} "
                "--force` to forcefully destroy the deployment", fg="red"
            )
            click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)
        sys.exit(1)


@dc.command(name="status", help="Shows the deployment status of the given deployment")
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be status checked",
    required=True
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
    required=True
)
@click.option(
    "--force",
    is_flag=True,
    help="Forcefully destroys all the deployed components",
)
def dc_deployment_destroy(deployment_id: str, force: bool):
    is_destroyed = dc_deployment_manager.destroy(scripts_dir, deployment_id, force)
    if not is_destroyed:
        destroy_failed_text = click.style(
            f"Error destroying deployment\n", fg="red"
        )
        next_command_text = click.style(
            f"Please run `syntho-cli dc destroy --deployment-id {deployment_id} "
            "--force` to forcefully destroy the deployment", fg="red"
        )
        click.echo(f"\n\n{destroy_failed_text}{next_command_text}", err=True)


@dc.command(name="deployments", help="Shows existing deployments and their statuses")
def k8s_deployments():
    deployments = dc_deployment_manager.get_deployments(scripts_dir)
    as_yaml = yaml.dump(deployments, default_flow_style=False)
    click.echo(as_yaml)


@utilities.command(name="prepull-images", help="Pulls Syntho's images into a trusted registry")
@click.option(
    "--trusted-registry",
    type=str,
    help="Specify the registry for images to be pulled into",
    required=True
)
@click.option(
    "--syntho-registry-user",
    type=str,
    help="Specify the Syntho docker image registry user that is provided by Syntho team",
    required=True
)
@click.option(
    "--syntho-registry-pwd",
    type=str,
    help="Specify the Syntho docker image registry password that is provided by Syntho team",
    required=True
)
@click.option(
    "--version",
    type=str,
    help=("Specify a version for Syntho stack."),
    required=True
)
@click.option(
    "--arch",
    type=str,
    help=("Specify the architecture. Default: amd"),
    default="amd",
    required=False
)
@click.option(
    "--docker-config",
    type=str,
    help=("Specify the default docker config.json path. Default: ~/.docker/config.json"),
    default="",
    required=False,
    callback=validate_docker_config
)
def prepull_images(trusted_registry: str,
                   syntho_registry_user: str,
                   syntho_registry_pwd: str,
                   version: str,
                   arch: str,
                   docker_config: str):
    arch = arch.lower()
    if not utils.is_arch_supported(arch):
        raise click.ClickException(
            f"Unsupported architecture: {arch}. Only AMD/ARM is supported."
        )

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
        pull_failed_text = click.style(
            f"Error pulling images. Error: {err}\n", fg="red"
        )
        click.echo(f"\n\n{pull_failed_text}", err=True)



if __name__ == '__main__':
    cli()

