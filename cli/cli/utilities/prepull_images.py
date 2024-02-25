import os
import shutil
import time
import click
import base64
import json


from cli.utils import (thread_safe, with_working_directory, DeploymentResult,
                       get_deployments_dir, CleanUpLevel, run_script)


def start(
    scripts_dir,
    version,
    arch,
    trusted_registry,
    syntho_registry_user,
    syntho_registry_pwd,
    docker_config_json_path,
):
    make_utilities_dir(scripts_dir)
    prepull_images_file_dir = generate_prepull_images_dir(scripts_dir)
    acquired = check_acquired(prepull_images_file_dir)
    if acquired:
        return False, ("There is an active prepull-images process, "
                       "please wait until it is done, or terminate the existing process")

    make_prepull_images_dir(scripts_dir)
    acquire(prepull_images_file_dir)
    time.sleep(2)

    env_file_path = make_env_file(
        prepull_images_file_dir,
        version,
        arch,
        trusted_registry,
        syntho_registry_user,
        syntho_registry_pwd,
    )

    # step 1 validation
    set_status(prepull_images_file_dir, "validating")
    result = validate(scripts_dir, env_file_path)
    if not result:
        release(prepull_images_file_dir)
        return False, "Confirmation has been failed, please retry"

    # step 2 authenticating with syntho registry
    set_status(prepull_images_file_dir, "authenticating")
    result = authenticate_syntho_registry(scripts_dir, env_file_path)
    if not result:
        release(prepull_images_file_dir)
        return False, "Authentication has been failed, please retry"

    # step 3 pulling images
    set_status(prepull_images_file_dir, "pulling")
    result, err = pull(scripts_dir, env_file_path, docker_config_json_path)
    if not result:
        release(prepull_images_file_dir)
        return False, "Pulling images has been failed, please retry" if not err else err

    # step 4 deauthenticating with syntho registry
    set_status(prepull_images_file_dir, "deauthenticating")
    result = deauthenticate_syntho_registry(scripts_dir, env_file_path)
    if not result:
        release(prepull_images_file_dir)
        return False, "Removing Syntho registry credentials has been failed, please retry"

    set_status(prepull_images_file_dir, "completed")

    release(prepull_images_file_dir)

    return True, None


def make_utilities_dir(scripts_dir):
    utilities_dir = generate_utilities_dir(scripts_dir)
    if not os.path.exists(utilities_dir):
        os.makedirs(utilities_dir)


def make_prepull_images_dir(scripts_dir):
    prepull_images_file_dir = generate_prepull_images_dir(scripts_dir)
    if os.path.exists(prepull_images_file_dir):
        shutil.rmtree(prepull_images_file_dir)

    os.makedirs(prepull_images_file_dir)


def make_env_file(
    prepull_images_file_dir,
    version,
    arch,
    trusted_registry,
    syntho_registry_user,
    syntho_registry_pwd,
):
    env = {
        "TRUSTED_REGISTRY": trusted_registry,
        "ARCH": arch,
        "REGISTRY_USER": syntho_registry_user,
        "REGISTRY_PWD": syntho_registry_pwd,
        "SYNTHO_REGISTRY": "syntho.azurecr.io",
        "VERSION": version,
    }
    env_file_path = f"{prepull_images_file_dir}/.env"
    with open(env_file_path, "w") as file:
        for key, value in env.items():
            if value:
                file.write(f"{key}={value}\n")
            else:
                file.write(f"{key}=\n")
    return env_file_path


def set_status(prepull_images_file_dir, status):
    status_file_path = f"{prepull_images_file_dir}/status"
    with open(status_file_path, "w") as file:
        file.write(status)


def generate_utilities_dir(scripts_dir):
    return f"{scripts_dir}/utilities"


def generate_prepull_images_dir(scripts_dir):
    return f"{generate_utilities_dir(scripts_dir)}/prepull-images"


def get_status(scripts_dir):
    prepull_images_dir = generate_prepull_images_dir(scripts_dir)
    if not os.path.exists(prepull_images_dir):
        return "unknown"

    status_file_path = f"{prepull_images_dir}/status"
    if not os.path.exists(status_file_path):
        return "unknown"

    with open(status_file_path, "r") as file:
        status = file.read()

    return status


def check_acquired(file_dir):
    path = f"{file_dir}/.lock"
    if os.path.exists(path):
        return True
    return False


def acquire(file_dir):
    path = f"{file_dir}/.lock"
    with open(path, "a") as _:
        pass


def release(file_dir):
    path = f"{file_dir}/.lock"
    os.remove(path)


def validate(scripts_dir, env_file_path):
    click.echo("Step 1: Confirmation;")
    prepull_images_dir = generate_prepull_images_dir(scripts_dir)
    result = run_script(
        scripts_dir,
        prepull_images_dir,
        "validate-prepull-images-process.sh",
        **{"CUSTOM_ENV_FILE_PATH": env_file_path}
    )
    return result.exitcode == 0


@with_working_directory
def authenticate_syntho_registry(scripts_dir, env_file_path):
    click.echo("Step 2: Authentication;")
    prepull_images_dir = generate_prepull_images_dir(scripts_dir)
    os.chdir(prepull_images_dir)
    result = run_script(
        scripts_dir,
        prepull_images_dir,
        "authenticate-syntho-registry.sh"
    )
    return result.exitcode == 0


def pull(scripts_dir, env_file_path, docker_config_json_path):
    click.echo("Step 3: Pulling Images Into Trusted Registry;")

    docker_config_json_path = os.path.expanduser(docker_config_json_path)
    docker_config = docker_config_json_path.replace("/config.json", "")
    if not os.path.exists(docker_config):
        return False, f"There is no docker config found in this path: {docker_config_json_path}"
    prepull_images_dir = generate_prepull_images_dir(scripts_dir)
    result = run_script(
        scripts_dir,
        prepull_images_dir,
        "prepull-images.sh",
        **{"DOCKER_CONFIG": docker_config}
    )
    return result.exitcode == 0, None


@with_working_directory
def deauthenticate_syntho_registry(scripts_dir, env_file_path):
    click.echo("Step 4: Removing authentication credentials;")
    prepull_images_dir = generate_prepull_images_dir(scripts_dir)
    os.chdir(prepull_images_dir)
    result = run_script(
        scripts_dir,
        prepull_images_dir,
        "deauthenticate-syntho-registry.sh"
    )
    return result.exitcode == 0
