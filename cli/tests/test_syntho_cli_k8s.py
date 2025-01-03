from pathlib import Path
from unittest import TestCase, mock

import yaml
from click.testing import CliRunner

from cli import syntho_cli
from cli.utils import DeploymentResult


class TestK8sStartDeploymentHappyPath(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output = """
-- Syntho stack is going to be deployed (Kubernetes) (Architecture: amd64) --


Deployment is successful. See helpful commands below.

Deployment status: syntho-cli k8s status --deployment-id k8s-123456789
Destroy deployment: syntho-cli k8s destroy --deployment-id k8s-123456789
Update release: syntho-cli k8s update --deployment-id k8s-123456789 --new-version <version>
See all releases: syntho-cli releases
"""

        self.sample_kubeconfig_content = """
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://my-cluster.example.com
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JS...
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
current-context: my-context
users:
- name: my-user
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JS...
    client-key-data: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCg==
"""

        self.get_architecture_patch = mock.patch("cli.syntho_cli.utils.get_architecture")
        self.k8s_deployment_start_patch = mock.patch("cli.syntho_cli.k8s_deployment_manager.start")
        self.mock_get_version_patch = mock.patch("cli.syntho_cli.get_version")
        self.mock_get_releases_patch = mock.patch("cli.syntho_cli.get_releases")

        self.mock_get_architecture = self.get_architecture_patch.start()
        self.mock_k8s_deployment_start = self.k8s_deployment_start_patch.start()
        self.mock_get_version = self.mock_get_version_patch.start()
        self.mock_get_releases = self.mock_get_releases_patch.start()

        self.mock_get_architecture.return_value = "amd"
        self.mock_k8s_deployment_start.return_value = DeploymentResult(
            succeeded=True,
            deployment_id="k8s-123456789",
            error=None,
            deployment_status="completed",
        )
        self.mock_get_version.return_value = "2.0.0"
        self.mock_get_releases.return_value = [{"name": "1.0.0"}]

    def tearDown(self):
        self.get_architecture_patch.stop()
        self.k8s_deployment_start_patch.stop()
        self.mock_get_version_patch.stop()
        self.mock_get_releases_patch.stop()

    def test_deployment_with_kubeconfig_content_and_registry_creds(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
                "--kubeconfig",
                self.sample_kubeconfig_content,
                "--version",
                "1.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.output.strip(), self.expected_output.strip())
        self.mock_get_architecture.assert_called()
        self.mock_k8s_deployment_start.assert_called_with(
            syntho_cli.scripts_dir,
            "my-license-key",
            "syntho-user",
            "syntho-pwd",
            self.sample_kubeconfig_content,
            "amd",
            "1.0.0",
            "",
            False,
            False,
            "2.0.0",
            False,
        )

    def test_deployment_with_kubeconfig_file_path_and_registry_creds(self):
        safe_load_return_value = yaml.safe_load(self.sample_kubeconfig_content)
        with (
            mock.patch("cli.syntho_cli.yaml.safe_load") as mock_safe_load,
            mock.patch("cli.syntho_cli.open") as mock_open,
        ):
            mock_open.return_value = mock.MagicMock()
            mock_safe_load.return_value = safe_load_return_value

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--registry-user",
                    "syntho-user",
                    "--registry-pwd",
                    "syntho-pwd",
                    "--kubeconfig",
                    "kubeconfig.yaml",
                    "--version",
                    "1.0.0",
                ],
            )

            self.assertEqual(result.exit_code, 0)
            self.assertEqual(result.output.strip(), self.expected_output.strip())
            self.mock_get_architecture.assert_called()
            self.mock_k8s_deployment_start.assert_called_with(
                syntho_cli.scripts_dir,
                "my-license-key",
                "syntho-user",
                "syntho-pwd",
                "kubeconfig.yaml",
                "amd",
                "1.0.0",
                "",
                False,
                False,
                "2.0.0",
                False,
            )
            mock_open.assert_called_once_with("kubeconfig.yaml", "r")

    def test_deployment_from_trusted_image_registry(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.prepull_images_manager.get_status") as mock_get_status,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "completed"

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--kubeconfig",
                    self.sample_kubeconfig_content,
                    "--version",
                    "1.0.0",
                    "--trusted-registry-image-pull-secret",
                    "my-image-pull-secret",
                    "--use-trusted-registry",
                ],
            )

            self.assertEqual(result.exit_code, 0)
            self.assertEqual(result.output.strip(), self.expected_output.strip())
            self.mock_get_architecture.assert_called()
            self.mock_k8s_deployment_start.assert_called_with(
                syntho_cli.scripts_dir,
                "my-license-key",
                "u",
                "p",
                self.sample_kubeconfig_content,
                "amd",
                "1.0.0",
                "my-image-pull-secret",
                False,
                True,
                "2.0.0",
                False,
            )


class TestK8sStartDeploymentValidationErrors(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output_incorrect_kubeconfig = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Invalid value for '--kubeconfig': KUBECONFIG is neither a valid YAML string nor a path to a valid YAML file: {home}/.kube/config
        """  # noqa: E501

        self.expected_output_template_for_missing_param = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Missing option '--{missing}'.
"""

        self.expected_output_for_two_different_deployment_approach = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Either provide '--registry-user' and '--registry-pwd' or use '--use-trusted-registry'.
"""
        self.expected_output_for_trusted_registry_missing_image_pull_secret = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: --trusted-registry-image-pull-secret should be provided when --use-trusted-registry is used
"""
        self.expected_output_invalid_version = """
Usage: deployment [OPTIONS]
Try 'deployment --help' for help.

Error: Given application stack version (1.2.0) could not be found. Available versions:
1.0.0
"""

        self.sample_kubeconfig_content = """
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://my-cluster.example.com
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JS...
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
current-context: my-context
users:
- name: my-user
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JS...
    client-key-data: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCg==
"""

    def assert_missing_param(self, result, missing):
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(
            result.output.strip(), self.expected_output_template_for_missing_param.format(missing=missing).strip()
        )

    def assert_missing_kubeconfig(self, result, home):
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_incorrect_kubeconfig.format(home=home).strip())

    # TODO: Remove test as default for kubeconfig has been setup (home/<user>/.kube/config)
    def test_deployment_without_kubeconfig(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
            ],
        )
        home_folder = Path.home()
        kubeconfig = Path(f"{home_folder}/.kube/config")
        if kubeconfig.is_file():
            self.assert_missing_param(result, "version")
        else:
            self.assert_missing_kubeconfig(result, home_folder)

    def test_deployment_without_license_key(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
                "--kubeconfig",
                self.sample_kubeconfig_content,
                "--version",
                "1.0.0",
            ],
        )

        self.assert_missing_param(result, "license-key")

    def test_deployment_without_version(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-user",
                "syntho-user",
                "--registry-pwd",
                "syntho-pwd",
                "--kubeconfig",
                self.sample_kubeconfig_content,
            ],
        )
        print(result.output)
        self.assert_missing_param(result, "version")

    def test_deployment_without_registry_user(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-pwd",
                "syntho-pwd",
                "--kubeconfig",
                self.sample_kubeconfig_content,
                "--version",
                "1.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_for_two_different_deployment_approach.strip())

    def test_deployment_without_registry_pwd(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment,
            [
                "--license-key",
                "my-license-key",
                "--registry-user",
                "syntho-user",
                "--kubeconfig",
                self.sample_kubeconfig_content,
                "--version",
                "1.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_for_two_different_deployment_approach.strip())

    def test_deployment_with_trusted_registry_without_image_pull_secret(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.prepull_images_manager.get_status") as mock_get_status,
            mock.patch("cli.syntho_cli.get_releases") as mock_get_releases,
        ):
            mock_path_exists.return_value = True
            mock_get_status.return_value = "completed"
            mock_get_releases.return_value = [{"name": "1.0.0"}]

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--use-trusted-registry",
                    "--kubeconfig",
                    self.sample_kubeconfig_content,
                    "--version",
                    "1.0.0",
                ],
            )

            self.assertEqual(result.exit_code, 2)
            self.assertEqual(
                result.output.strip(), self.expected_output_for_trusted_registry_missing_image_pull_secret.strip()
            )

    def test_invalid_version(self):
        with (
            mock.patch("cli.syntho_cli.os.path.exists") as mock_path_exists,
            mock.patch("cli.syntho_cli.get_releases") as mock_get_releases,
        ):
            mock_path_exists.return_value = True
            mock_get_releases.return_value = [{"name": "1.0.0"}]

            result = self.runner.invoke(
                syntho_cli.k8s_deployment,
                [
                    "--license-key",
                    "my-license-key",
                    "--registry-user",
                    "syntho-user",
                    "--registry-pwd",
                    "syntho-pwd",
                    "--kubeconfig",
                    self.sample_kubeconfig_content,
                    "--version",
                    "1.2.0",
                ],
            )

            self.assertEqual(result.exit_code, 2)
            self.assertEqual(result.output.strip(), self.expected_output_invalid_version.strip())


class TestK8sUpdateDeploymentHappyPath(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output = """
-- Syntho stack is going to be updated from (1.0.0) to (1.1.0) (Kubernetes) --


The application stack has been successfully rolled out to a given version. See helpful commands below.

Deployment status: syntho-cli k8s status --deployment-id k8s-123456789
Destroy deployment: syntho-cli k8s destroy --deployment-id k8s-123456789
Update release: syntho-cli k8s update --deployment-id k8s-123456789 --new-version <version>
See all releases: syntho-cli releases
"""

        self.deployment = {"version": "1.0.0", "deployment_id": "k8s-123456789"}

        self.get_deployment_patch = mock.patch("cli.syntho_cli.k8s_deployment_manager.get_deployment")
        self.get_releases_patch = mock.patch("cli.syntho_cli.get_releases")
        self.update_k8s_deployment_patch = mock.patch("cli.syntho_cli.k8s_deployment_manager.update_k8s_deployment")

        self.mock_get_deployment = self.get_deployment_patch.start()
        self.mock_get_releases = self.get_releases_patch.start()
        self.mock_update_k8s_deployment = self.update_k8s_deployment_patch.start()

        self.mock_get_deployment.return_value = self.deployment
        self.mock_get_releases.return_value = [{"name": "1.1.0"}, {"name": "2.0.0"}]
        self.mock_update_k8s_deployment.return_value = DeploymentResult(
            succeeded=True,
            deployment_id="k8s-123456789",
            error=None,
            deployment_status="completed",
        )

    def tearDown(self):
        self.get_deployment_patch.stop()
        self.get_releases_patch.stop()
        self.update_k8s_deployment_patch.stop()

    def test_update_deployment(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment_update,
            [
                "--deployment-id",
                "k8s-123456789",
                "--new-version",
                "1.1.0",
            ],
        )

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.output.strip(), self.expected_output.strip())
        self.mock_get_deployment.assert_called_with(syntho_cli.scripts_dir, "k8s-123456789")
        self.mock_get_releases.assert_called_with(with_compatibility="1.0.0")
        self.mock_update_k8s_deployment.assert_called_with(
            syntho_cli.scripts_dir,
            "k8s-123456789",
            "1.1.0",
        )


class TestK8sUpdateDeploymentSadPath(TestCase):
    def setUp(self):
        self.runner = CliRunner()

        self.expected_output_for_same_version = """
Usage: update [OPTIONS]
Try 'update --help' for help.

Error: Given version (1.0.0) is already deployed within the current stack (1.0.0).
Compatible releases:


"""

        self.expected_output_for_not_existing_version = """
Usage: update [OPTIONS]
Try 'update --help' for help.

Error: Given application stack version (2.0.0) could not be found. Available versions:
1.1.0

"""

        self.expected_output_for_not_compatible_version = """
Usage: update [OPTIONS]
Try 'update --help' for help.

Error: Given version (2.0.0) is not compatible within the current stack (1.0.0).
Compatible releases:
1.1.0

"""

        self.deployment = {"version": "1.0.0", "deployment_id": "k8s-123456789"}

        self.get_deployment_patch = mock.patch("cli.syntho_cli.k8s_deployment_manager.get_deployment")
        self.get_releases_patch = mock.patch("cli.syntho_cli.get_releases")
        self.update_k8s_deployment_patch = mock.patch("cli.syntho_cli.k8s_deployment_manager.update_k8s_deployment")

        self.mock_get_deployment = self.get_deployment_patch.start()
        self.mock_get_releases = self.get_releases_patch.start()
        self.mock_update_k8s_deployment = self.update_k8s_deployment_patch.start()

        self.mock_get_deployment.return_value = self.deployment
        self.mock_get_releases.return_value = [{"name": "1.0.0"}]
        self.mock_update_k8s_deployment.return_value = DeploymentResult(
            succeeded=True,
            deployment_id="k8s-123456789",
            error=None,
            deployment_status="completed",
        )

    def tearDown(self):
        self.get_deployment_patch.stop()
        self.get_releases_patch.stop()
        self.update_k8s_deployment_patch.stop()

    def test_update_deployment_same_version(self):
        result = self.runner.invoke(
            syntho_cli.k8s_deployment_update,
            [
                "--deployment-id",
                "k8s-123456789",
                "--new-version",
                "1.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_for_same_version.strip())
        self.mock_get_deployment.assert_called_with(syntho_cli.scripts_dir, "k8s-123456789")
        self.mock_get_releases.assert_called_with(with_compatibility="1.0.0")

    def test_update_deployment_not_existing_version(self):
        self.mock_get_releases.return_value = [{"name": "1.1.0"}]
        result = self.runner.invoke(
            syntho_cli.k8s_deployment_update,
            [
                "--deployment-id",
                "k8s-123456789",
                "--new-version",
                "2.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_for_not_existing_version.strip())
        self.mock_get_releases.assert_called_with()

    def test_update_deployment_not_compatible_version(self):
        self.mock_get_releases.side_effect = [
            [{"name": "1.0.0"}, {"name": "1.1.0"}, {"name": "2.0.0"}, {"name": "3.0.0"}],
            [{"name": "1.0.0"}, {"name": "1.1.0"}],
        ]
        result = self.runner.invoke(
            syntho_cli.k8s_deployment_update,
            [
                "--deployment-id",
                "k8s-123456789",
                "--new-version",
                "2.0.0",
            ],
        )

        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.output.strip(), self.expected_output_for_not_compatible_version.strip())
        self.mock_get_deployment.assert_called_with(syntho_cli.scripts_dir, "k8s-123456789")
        self.mock_get_releases.assert_called_with(with_compatibility="1.0.0")
