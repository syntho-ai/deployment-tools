import os
import fcntl
import platform

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
