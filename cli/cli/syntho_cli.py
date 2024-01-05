import sys
import os
import click
import yaml
from typing import Optional


from cli import utils
from cli import k8s_deployment as k8s_deployment_manager


syntho_cli_dir = os.path.dirname(os.path.abspath(__file__))
scripts_dir = os.path.join(syntho_cli_dir, "scripts")


@click.group()
def cli():
    pass

@cli.group(help="Manages Kubernetes deployments")
def k8s():
    pass

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
    required=True
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
    version: Optional[str],
    skip_configuration: bool,
):
    arch = utils.platform_arch()
    if not arch.supported():
        raise click.ClickException(
            f"Unsupported architecture: {arch.value}. Only AMD/ARM is supported."
        )
    starting_text = click.style(
        "-- Syntho stack is going to be deployed --", fg="white", blink=True, bold=True,
    )
    click.echo(f"{starting_text}\n")

    result = k8s_deployment_manager.start(
        scripts_dir,
        license_key,
        registry_user,
        registry_pwd,
        kubeconfig,
        arch.value,
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


if __name__ == '__main__':
    cli()
