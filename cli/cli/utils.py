import platform
from enum import Enum


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
