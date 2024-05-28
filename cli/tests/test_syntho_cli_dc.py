from unittest import TestCase, mock

# import yaml
from click.testing import CliRunner

from cli import syntho_cli
from cli.utils import DeploymentResult


class TestDCStartDeploymentHappyPath(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output = """
-- Syntho stack is going to be deployed (Docker Compose) (Architecture: amd64) --


Deployment is successful. See helpful commands below.

Deployment status: syntho-cli dc status --deployment-id dc-123456789
Destroy deployment: syntho-cli dc destroy --deployment-id dc-123456789
"""

        self.license_key = "my-license-key"
        self.registry_user = "syntho-user"
        self.registry_pwd = "syntho-pwd"
        self.default_docker_config = "~/.docker/config.json"
        self.default_docker_host = "unix:///var/run/docker.sock"
        self.remote_docker_host = "ssh://syntho@192.168.1.100"
        self.remote_docker_host_ssh_private_key = "~/home/syntho/.ssh/id_rsa"
        self.syntho_stack_version = "1.0.0"
        self.cli_version = "2.0.0"

        self.get_architecture_patch = mock.patch("cli.syntho_cli.utils.get_architecture")
        self.dc_deployment_start_patch = mock.patch("cli.syntho_cli.dc_deployment_manager.start")
        self.mock_get_version_patch = mock.patch("cli.syntho_cli.get_version")

        self.mock_get_architecture = self.get_architecture_patch.start()
        self.mock_dc_deployment_start = self.dc_deployment_start_patch.start()
        self.mock_get_version = self.mock_get_version_patch.start()

        self.mock_get_architecture.return_value = "amd"
        self.mock_dc_deployment_start.return_value = DeploymentResult(
            succeeded=True,
            deployment_id="dc-123456789",
            error=None,
            deployment_status="completed",
        )
        self.mock_get_version.return_value = self.cli_version

    def tearDown(self):
        self.get_architecture_patch.stop()
        self.dc_deployment_start_patch.stop()
        self.mock_get_version_patch.stop()

    def test_deployment_to_default_docker_daemon(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--license-key",
                self.license_key,
                "--registry-user",
                self.registry_user,
                "--registry-pwd",
                self.registry_pwd,
                "--version",
                "1.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.output.strip(), self.expected_output.strip())
        self.mock_get_architecture.assert_called()
        self.mock_dc_deployment_start.assert_called_with(
            syntho_cli.scripts_dir,
            self.license_key,
            self.registry_user,
            self.registry_pwd,
            self.default_docker_host,
            None,
            "amd",
            self.syntho_stack_version,
            self.default_docker_config,
            False,
            False,
            False,
            self.cli_version,
            False,
        )

    def test_deployment_to_default_docker_daemon_skip_configuration(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--license-key",
                self.license_key,
                "--registry-user",
                self.registry_user,
                "--registry-pwd",
                self.registry_pwd,
                "--version",
                "1.0.0",
                "--skip-configuration",
            ],
        )

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.output.strip(), self.expected_output.strip())
        self.mock_get_architecture.assert_called()
        self.mock_dc_deployment_start.assert_called_with(
            syntho_cli.scripts_dir,
            self.license_key,
            self.registry_user,
            self.registry_pwd,
            self.default_docker_host,
            None,
            "amd",
            self.syntho_stack_version,
            self.default_docker_config,
            True,
            False,
            False,
            self.cli_version,
            False,
        )

    def test_deployment_to_remote_docker_daemon(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--license-key",
                self.license_key,
                "--registry-user",
                self.registry_user,
                "--registry-pwd",
                self.registry_pwd,
                "--version",
                "1.0.0",
                "--docker-host",
                self.remote_docker_host,
                "--docker-ssh-user-private-key",
                self.remote_docker_host_ssh_private_key,
            ],
        )

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.output.strip(), self.expected_output.strip())
        self.mock_get_architecture.assert_called()
        self.mock_dc_deployment_start.assert_called_with(
            syntho_cli.scripts_dir,
            self.license_key,
            self.registry_user,
            self.registry_pwd,
            self.remote_docker_host,
            self.remote_docker_host_ssh_private_key,
            "amd",
            self.syntho_stack_version,
            self.default_docker_config,
            False,
            False,
            False,
            self.cli_version,
            False,
        )

    def test_deployment_from_trusted_registry(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.prepull_images_manager.get_status") as mock_get_status,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "completed"

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    self.license_key,
                    "--version",
                    "1.0.0",
                    "--use-trusted-registry",
                ],
            )

            self.assertEqual(result.exit_code, 0)
            self.assertEqual(result.output.strip(), self.expected_output.strip())
            self.mock_get_architecture.assert_called()
            self.mock_dc_deployment_start.assert_called_with(
                syntho_cli.scripts_dir,
                self.license_key,
                "u",
                "p",
                self.default_docker_host,
                None,
                "amd",
                self.syntho_stack_version,
                self.default_docker_config,
                False,
                True,
                False,
                self.cli_version,
                False,
            )

    def test_deployment_from_offline_registry(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.offline_ops_manager.get_status") as mock_get_status,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "completed"

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    self.license_key,
                    "--version",
                    "1.0.0",
                    "--use-offline-registry",
                ],
            )

            self.assertEqual(result.exit_code, 0)
            self.assertEqual(result.output.strip(), self.expected_output.strip())
            self.mock_get_architecture.assert_called()
            self.mock_dc_deployment_start.assert_called_with(
                syntho_cli.scripts_dir,
                self.license_key,
                "u",
                "p",
                self.default_docker_host,
                None,
                "amd",
                self.syntho_stack_version,
                self.default_docker_config,
                False,
                False,
                True,
                self.cli_version,
                False,
            )


class TestDCStartDeploymentValidationErrors(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output_template_for_missing_param = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Missing option '--{missing}'.
"""

        self.expected_output_when_docker_config_doesnt_exist = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Invalid value for '--docker-config': given docker config.json path /foo/bar.config is not valid, please provide the config.json that current docker contex's daemon is using
"""  # noqa: E501

        self.expected_output_when_trusted_registry_is_not_ready = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Invalid value for '--use-trusted-registry': syntho-cli is not ready to deploy Syntho resources from a trusted registry yet. Please run 'syntho-cli utilities prepull-images --help' first for more info
"""  # noqa: E501

        self.expected_output_when_offline_registry_is_not_ready = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Invalid value for '--use-offline-registry': syntho-cli is not ready to deploy Syntho resources from the offline registry yet. Please run 'syntho-cli utilities activate-offline-mode --help' first for more info
"""  # noqa: E501

        self.expected_output_when_both_offline_and_trusted_is_used = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Either provide '--use-trusted-registry' or '--use-offline-registry'. Please check:
'syntho-cli utilities prepull-images --help'
'syntho-cli utilities activate-offline-mode --help'
"""  # noqa: E501

        self.expected_output_when_a_proper_creds_or_deployment_registry_is_not_provided = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Either provide '--registry-user' and '--registry-pwd' or use '--use-trusted-registry'.
"""

    def assert_missing_param(self, result, missing):
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(
            result.output.strip(), self.expected_output_template_for_missing_param.format(missing=missing).strip()
        )

    def assert_with_expected_output(self, result, expected_output):
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), expected_output.strip())

    def test_deployment_without_license_key(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
                "--version",
                "1.0.0",
            ],
        )

        self.assert_missing_param(result, "license-key")

    def test_deployment_without_version(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
            ],
        )

        self.assert_missing_param(result, "version")

    def test_given_docker_config_doesnt_exist(self):
        with mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists:
            mock_path_exists.return_value = False

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--registry-user",
                    "syntho-user",
                    "--registry-pwd",
                    "syntho-pwd",
                    "--version",
                    "1.0.0",
                    "--docker-config",
                    "/foo/bar.config",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_docker_config_doesnt_exist)

    def test_deployment_with_trusted_registry_when_it_is_not_ready(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.prepull_images_manager.get_status") as mock_get_status,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "in-progress"

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--version",
                    "1.0.0",
                    "--use-trusted-registry",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_trusted_registry_is_not_ready)

    def test_deployment_with_trusted_registry_when_it_doesnt_exist(self):
        with mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists:
            mock_path_exists.return_value = False

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--version",
                    "1.0.0",
                    "--use-trusted-registry",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_trusted_registry_is_not_ready)

    def test_deployment_with_offline_registry_when_it_is_not_ready(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.offline_ops_manager.get_status") as mock_get_status,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "in-progress"

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--version",
                    "1.0.0",
                    "--use-offline-registry",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_offline_registry_is_not_ready)

    def test_deployment_with_offline_registry_when_it_doesnt_exist(self):
        with mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists:
            mock_path_exists.return_value = False

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--version",
                    "1.0.0",
                    "--use-offline-registry",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_offline_registry_is_not_ready)

    def test_deployment_with_both_offline_and_trusted_registry(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.offline_ops_manager.get_status") as mock_get_status_offline,
            mock.patch("cli.syntho_cli.prepull_images_manager.get_status") as mock_get_status_trus,
        ):
            mock_path_exists.return_value = True
            mock_get_status_offline.return_value = "completed"
            mock_get_status_trus.return_value = "completed"

            result = self.runner.invoke(
                syntho_cli.dc_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--version",
                    "1.0.0",
                    "--use-offline-registry",
                    "--use-trusted-registry",
                ],
            )

            self.assert_with_expected_output(result, self.expected_output_when_both_offline_and_trusted_is_used)

    def test_deployment_either_provide_registry_creds_or_trusted_or_offline_registry(self):
        result = self.runner.invoke(
            syntho_cli.dc_deployment,
            [
                "--license-key",
                "my-license-key",
                "--version",
                "1.0.0",
            ],
        )

        self.assert_with_expected_output(
            result, self.expected_output_when_a_proper_creds_or_deployment_registry_is_not_provided
        )
