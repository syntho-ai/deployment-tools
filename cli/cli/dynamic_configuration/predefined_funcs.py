import re
from typing import Any, Tuple

from cli.utils import run_script


def regex(deployment_dir, pattern, text) -> bool:
    """
    Check if the provided text matches the given regex pattern.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param pattern: The regex pattern to match against.
    :param text: The text to be matched.
    :return: True if the text matches the pattern, False otherwise.
    """
    if not bool(re.match(pattern, text)):
        raise Exception("invalid value")


def lowercase(deployment_dir, val) -> str:
    """
    Convert the given string to lowercase.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param val: The string to be converted.
    :return: The lowercase version of the input string.
    """
    return val.lower()


def kubectlget(deployment_dir, *args) -> Tuple[bool, str]:
    """
    Placeholder function to execute a kubectl get command.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param args: The arguments for the kubectl get command.
    :return: The output of the kubectl get command.
    """
    length = len(args)
    args_with_spaces = [f"{arg}{'' if i == length - 1 else ' '}" for i, arg in enumerate(args)]
    params = concatenate(deployment_dir, *args_with_spaces)
    scripts_dir, _, _ = deployment_dir.rsplit("/", 2)
    result = run_script(scripts_dir, deployment_dir, "kubectlget.sh", capture_output=True, **{"PARAMS": params})
    if result.exitcode != 0:
        return ""
    return result.output


def returnasis(deployment_dir, val) -> Any:
    """
    Return the input value as is.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param val: The value to be returned.
    :return: The input value, unchanged.
    """
    return val


def concatenate(deployment_dir, *args) -> str:
    """
    Concatenate the given arguments into a single string.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param args: The arguments to be concatenated.
    :return: A single string formed by concatenating the input arguments.
    """
    return "".join([str(arg) for arg in args])


def divide(deployment_dir, dividend, divisor):
    """
    Divide the dividend by the divisor and return the result.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
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

    return int(dividend / divisor)


def onlythesevalues(deployment_dir, given_value: str, allowed_values: str) -> bool:
    """
    Check if the given value is one of the allowed values.

    :param deployment_dir: The deployment_dir for a specific deployment that holds.
    :param given_value: The value to be checked.
    :param allowed_values: A comma-separated string of allowed values.
    :return: True if the given value is one of the allowed values, False otherwise.
    :raises ValueError: If the given value is not one of the allowed values.
    """

    allowed_values_list = allowed_values.split(",")
    if given_value not in allowed_values_list:
        raise ValueError(f"Invalid value: {given_value}. Allowed values are: {allowed_values_list}")

    return True
