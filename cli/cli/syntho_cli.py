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

@cli.command()
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
def k8s_deployment(
    license_key: str,
    registry_user: str,
    registry_pwd: str,
    kubeconfig: str,
    version: Optional[str],
):
    arch = utils.platform_arch()
    if not arch.supported():
        raise click.ClickException(
            f"Unsupported architecture: {arch.value}. Only AMD/ARM is supported."
        )

    result = k8s_deployment_manager.start(
        scripts_dir,
        license_key,
        registry_user,
        registry_pwd,
        kubeconfig,
        arch.value,
        version,
    )

    if result.succeeded:
        click.echo(
            "\n"
            "Deployment is successful. See helpful commands below.\n\n"
            f"Deployment status: syntho-cli k8s-deployment-status --deployment-id {result.deployment_id}\n"
            f"Destroy deployment: syntho-cli k8s-deployment-destroy --deployment-id {result.deployment_id}\n"
            f"Get active deployment: syntho-cli k8s-deployment-active\n"
        )
    else:
        click.echo(f"Error deploying to kubernetes: {result.error}", err=True)
        click.echo(f"Cleaning things up", err=True)
        k8s_deployment_manager.cleanup(scripts_dir, result.deployment_id, result.deployment_status)
        sys.exit(1)


@cli.command()
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


@cli.command()
@click.option(
    "--deployment-id",
    type=str,
    help="Specify the deployment id to be destroyed",
    required=True
)
def k8s_deployment_destroy(deployment_id: str):
    k8s_deployment_manager.destroy(scripts_dir, deployment_id)


@cli.command()
def k8s_deployments():
    deployments = k8s_deployment_manager.get_deployments(scripts_dir)
    as_yaml = yaml.dump(deployments, default_flow_style=False)
    click.echo(as_yaml)


if __name__ == '__main__':
    cli()
