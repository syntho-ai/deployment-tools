from unittest import mock

import pytest
from click.testing import CliRunner

from cli import syntho_cli


@pytest.fixture()
def mock_get_version():
    with mock.patch("cli.syntho_cli.metadata") as _mock_metadata:
        _mock_version = mock.MagicMock()
        _mock_version.return_value = "1.0.0"
        _mock_metadata.version = _mock_version
        yield _mock_version


def test_syntho_cli_help():
    expected_output = """
Usage: cli [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  dc         Manages Docker Compose Deployment
  k8s        Manages Kubernetes Deployments
  utilities  Utilities to streamline manual operations
  version
"""
    runner = CliRunner()
    result = runner.invoke(syntho_cli.cli, ["--help"])
    assert result.exit_code == 0
    assert result.output.strip() == expected_output.strip()


def test_syntho_cli_version(mock_get_version):
    runner = CliRunner()
    result = runner.invoke(syntho_cli.cli, ["version"])
    assert result.exit_code == 0
    assert result.output == "syntho-cli, 1.0.0\n"
    mock_get_version.assert_called_with("syntho-cli")
