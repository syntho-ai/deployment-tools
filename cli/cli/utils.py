import os
import fcntl
import subprocess
import click

from functools import wraps
from enum import Enum
from collections import namedtuple
from typing import Dict, NoReturn


def is_arch_supported(arch: str) -> bool:
    return arch in ["amd", "arm"]


def thread_safe(func):
    def wrapper(*args, **kwargs):
        deployments_dir = args[0] if args else kwargs.get(
            "deployments_dir", "/tmp")

        # Construct the lock file path
        lock_file_path = os.path.join(deployments_dir, ".lock")

        # Acquire the file-based lock
        with open(lock_file_path, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                return func(*args, **kwargs)
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)

    return wrapper


class ProgressBar:
    def __init__(self, message: str, total_steps: int, style: Dict = None):
        self.message = message
        self.total_steps = total_steps
        self.current_step = 0
        self.length = 20
        self.style = style

    def start(self):
        self.update_progress(0.1)
        final_message = self.make_final_message()
        click.echo(final_message)

    def update_progress(self, current_step: int):
        self.current_step = min(current_step, self.total_steps)

    def update(self, current_step: int):
        self.update_progress(current_step)
        self.current_step = min(current_step, self.total_steps)
        final_message = self.make_final_message()
        click.echo(f"\r{final_message}", nl=False)

    def get_progress_str(self):
        progress = self.current_step / self.total_steps
        progress_str = f"[{'#' * int(progress * self.length)}{'.' * (self.length - int(progress * self.length))}] [{int(progress * 100)}%]"
        return progress_str

    def make_final_message(self):
        final_message = f"{self.message}  -  {self.get_progress_str()}"
        if self.style is not None and isinstance(self.style, dict):
            final_message = click.style(f"{final_message}", **self.style)

        return final_message


def with_working_directory(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        original_dir = os.getcwd()

        try:
            result = func(*args, **kwargs)

            return result

        finally:
            os.chdir(original_dir)

    return wrapper


DeploymentResult = namedtuple("DeploymentResult", [
    "succeeded",
    "deployment_id",
    "error",
    "deployment_status",
])


SubprocessResult = namedtuple("SubprocessResult", [
    "succeeded",
    "output",
    "exitcode",
])


def get_deployments_dir(scripts_dir: str) -> str:
    deployments_dir = f"{scripts_dir}/deployments" 
    if not os.path.exists(deployments_dir):
        os.makedirs(deployments_dir)

    return deployments_dir


class CleanUpLevel(Enum):
    FULL = "full"
    DIR = "dir"
    NA = "not-applicable"


def run_script(scripts_dir:str,
               deployment_dir: str,
               script_name: str,
               capture_output: bool = False,
               **extra_env) -> SubprocessResult:
    env = {
        "DEPLOYMENT_DIR": deployment_dir,
        "PATH": os.environ.get("PATH", ""),
    }
    env.update(**extra_env)
    script_path = os.path.join(scripts_dir, script_name)

    try:
        if capture_output:
            res = subprocess.run([script_path], check=True, shell=False, env=env,
                                 capture_output=True, text=True)
        else:
            res = subprocess.run([script_path], check=True, shell=False, env=env)

        return SubprocessResult(
            succeeded=True,
            output=res.stdout.strip() if res.stdout else "",
            exitcode=res.returncode,
        )
    except subprocess.CalledProcessError as e:
        return SubprocessResult(succeeded=False, output=e.stderr, exitcode=e.returncode)
    except KeyboardInterrupt:
        return SubprocessResult(succeeded=False, output="", exitcode=1)
    except Exception as e:
        return SubprocessResult(succeeded=False, output="", exitcode=1)
