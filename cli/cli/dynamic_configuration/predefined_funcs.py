import re
from typing import Any, Tuple

from cli.utils import run_script


def regex(pattern, text) -> bool:
    """
    Check if the provided text matches the given regex pattern.

    :param pattern: The regex pattern to match against.
    :param text: The text to be matched.
    :return: True if the text matches the pattern, False otherwise.
    """
    return bool(re.match(pattern, text))


def lowercase(val) -> str:
    """
    Convert the given string to lowercase.

    :param val: The string to be converted.
    :return: The lowercase version of the input string.
    """
    return val.lower()


def kubectlget(deployment_dir, *args) -> Tuple[bool, str]:
    """
    Placeholder function to execute a kubectl get command.

    :param deployments_dir: The deployments_dir for a specific deployment that holds.
    :param args: The arguments for the kubectl get command.
    :return: The output of the kubectl get command.
    """
    length = len(args)
    args_with_spaces = [f"{arg}{"" if i == length - 1 else " "}" for i, arg in enumerate(args)]
    params = concatenate(*args_with_spaces)
    scripts_dir, _, _ = deployment_dir.rsplit("/", 2)
    result = run_script(scripts_dir, deployment_dir, "kubectlget.sh", capture_output=True, **{"PARAMS": params})
    return result.exitcode == 0, result.output


def returnasis(val) -> Any:
    """
    Return the input value as is.

    :param val: The value to be returned.
    :return: The input value, unchanged.
    """
    return val


def concatenate(*args) -> str:
    """
    Concatenate the given arguments into a single string.

    :param args: The arguments to be concatenated.
    :return: A single string formed by concatenating the input arguments.
    """
    return "".join([str(arg) for arg in args])


def divide(dividend, divisor):
    """
    Divide the dividend by the divisor and return the result.

    :param dividend: The value to be divided.
    :param divisor: The value to divide by.
    :return: The result of the division.
    :raises ValueError: If the dividend or divisor cannot be converted to an integer or if the divisor is zero.
    """
    if divisor == 0:
        raise ValueError("The divisor cannot be zero.")

    try:
        dividend = int(dividend)
        divisor = int(divisor)
    except Exception as exc:
        raise ValueError("Conversion error") from exc

    return dividend / divisor
