import os
import shutil
import time

import click

from cli.utils import (
    acquire,
    check_acquired,
    find_available_port,
    generate_utilities_dir,
    make_utilities_dir,
    release,
    run_script,
    set_status,
    with_working_directory,
)


def create_offline_registry(
    scripts_dir,
    version,
    arch,
    syntho_registry_user,
    syntho_registry_pwd,
    docker_config_json_path,
):
    make_utilities_dir(scripts_dir)
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    acquired = check_acquired(offline_registry_dir)
    if acquired:
        return False, (
            "There is an active activate-offline-mode process, "
            "please wait until it is done, or terminate the existing process"
        )

    make_offline_registry_dir(scripts_dir)
    acquire(offline_registry_dir)
    time.sleep(2)

    available_port = find_available_port(5020, 5050)
    if not available_port:
        return False, "There is no available port between 5000-5050"

    env_file_path = make_env_file(
        offline_registry_dir,
        version,
        arch,
        syntho_registry_user,
        syntho_registry_pwd,
        available_port,
    )

    # step 1 authenticating with syntho registry
    set_status(offline_registry_dir, "authenticating")
    result = authenticate_syntho_registry(scripts_dir, env_file_path)
    if not result:
        release(offline_registry_dir)
        return False, "Authentication has been failed, please retry"

    # step 2 creating an offline image registry
    set_status(offline_registry_dir, "creating-offline-registry")
    result, err = create_offline_image_registry(
        scripts_dir,
        env_file_path,
        docker_config_json_path,
        available_port,
    )
    if not result:
        release(offline_registry_dir)
        return False, "Offline registry creation has been failed, please retry" if not err else err

    # step 3 deauthenticating with syntho registry
    set_status(offline_registry_dir, "deauthenticating")
    result = deauthenticate_syntho_registry(scripts_dir, env_file_path)
    if not result:
        release(offline_registry_dir)
        return False, "Removing Syntho registry credentials has been failed, please retry"

    # step 4 packaging
    set_status(offline_registry_dir, "packaging")
    result = package_syntho_registry(scripts_dir, env_file_path)
    if not result:
        release(offline_registry_dir)
        return False, "Packaging Syntho registry has been failed, please retry"

    set_status(offline_registry_dir, "completed")

    release(offline_registry_dir)

    return True, None


def generate_offline_registry_dir(scripts_dir):
    return f"{generate_utilities_dir(scripts_dir)}/activate-offline-mode"


def generate_offline_registry_archive_path(scripts_dir):
    return f"{generate_utilities_dir(scripts_dir)}/activate-offline-mode.tar.gz"


def make_offline_registry_dir(scripts_dir):
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    if os.path.exists(offline_registry_dir):
        shutil.rmtree(offline_registry_dir)

    offline_registry_archive = generate_offline_registry_archive_path(scripts_dir)
    if os.path.isfile(offline_registry_archive):
        os.remove(offline_registry_archive)

    os.makedirs(offline_registry_dir)


def make_env_file(
    offline_registry_dir,
    version,
    arch,
    syntho_registry_user,
    syntho_registry_pwd,
    available_port,
):
    offline_registry = f"localhost:{available_port}"
    env = {
        "ARCH": arch,
        "REGISTRY_USER": syntho_registry_user,
        "REGISTRY_PWD": syntho_registry_pwd,
        "SYNTHO_REGISTRY": "syntho.azurecr.io",
        "VERSION": version,
        "AVAILABLE_PORT": available_port,
        "OFFLINE_REGISTRY": offline_registry,
    }
    env_file_path = f"{offline_registry_dir}/.env"
    with open(env_file_path, "w") as file:
        for key, value in env.items():
            if value:
                file.write(f"{key}={value}\n")
            else:
                file.write(f"{key}=\n")
    return env_file_path


@with_working_directory
def authenticate_syntho_registry(scripts_dir, env_file_path):
    click.echo("Step 1: Authentication;")
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    os.chdir(offline_registry_dir)
    result = run_script(scripts_dir, offline_registry_dir, "authenticate-syntho-registry.sh")
    return result.exitcode == 0


@with_working_directory
def deauthenticate_syntho_registry(scripts_dir, env_file_path):
    click.echo("Step 3: Removing authentication credentials;")
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    os.chdir(offline_registry_dir)
    result = run_script(scripts_dir, offline_registry_dir, "deauthenticate-syntho-registry.sh")
    return result.exitcode == 0


@with_working_directory
def create_offline_image_registry(scripts_dir, env_file_path, docker_config_json_path, available_port):
    click.echo("Step 2: Creating an offline image registry;")
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    os.chdir(offline_registry_dir)

    docker_config_json_path = os.path.expanduser(docker_config_json_path)
    docker_config = docker_config_json_path.replace("/config.json", "")
    if not os.path.exists(docker_config):
        return False, f"There is no docker config found in this path: {docker_config_json_path}"

    result = run_script(
        scripts_dir,
        offline_registry_dir,
        "create-offline-registry.sh",
        **{
            "DOCKER_CONFIG": docker_config,
        },
    )
    return result.exitcode == 0, None


@with_working_directory
def package_syntho_registry(scripts_dir, env_file_path):
    click.echo("Step 4: Packaging the registry;")
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    os.chdir(offline_registry_dir)
    archive_file_name = generate_offline_registry_archive_path(scripts_dir)

    result = run_script(
        scripts_dir, offline_registry_dir, "package-offline-registry.sh", **{"ARCHIVE_FILE_NAME": archive_file_name}
    )

    return result.exitcode == 0


def get_status(scripts_dir):
    offline_registry_dir = generate_offline_registry_dir(scripts_dir)
    if not os.path.exists(offline_registry_dir):
        return "unknown"

    status_file_path = f"{offline_registry_dir}/status"
    if not os.path.exists(status_file_path):
        return "unknown"

    with open(status_file_path, "r") as file:
        status = file.read()

    return status
