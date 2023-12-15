import os
import fcntl
import platform
import click

from enum import Enum
from typing import Dict, NoReturn


class Arch(Enum):
    AMD = "amd"
    ARM = "arm"
    UNKNOWN = "unknown"

    def supported(self):
        return self in [Arch.AMD, Arch.ARM]


def platform_arch() -> str:
    machine = platform.machine()

    if "x86" in machine:
        return Arch.AMD
    elif "arm" in machine:
        return Arch.ARM
    else:
        return Arch.UNKNOWN


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
