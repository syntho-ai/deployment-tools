import os
import shutil
import unittest
from unittest.mock import MagicMock, patch

from cli import pre_build


class TestMainFunction(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory for testing
        self.test_dir = "test_dir"
        os.makedirs(self.test_dir, exist_ok=True)

    def tearDown(self):
        # Remove the temporary directory after testing
        shutil.rmtree(self.test_dir)

    @patch("cli.pre_build.shutil.copytree")
    @patch("cli.pre_build.tarfile.open")
    @patch("cli.pre_build.shutil.rmtree")
    @patch("cli.pre_build.os.makedirs")
    @patch("cli.pre_build.os.path.exists")
    @patch("cli.pre_build.os.remove")
    def test_main_function(self, mock_remove, mock_path_exists, mock_makedirs, mock_rmtree, mock_open, mock_copytree):
        # Mock the necessary functions
        mock_tar_add = MagicMock()
        mock_open.return_value = MagicMock()
        mock_open.return_value.__enter__.return_value.add = mock_tar_add
        mock_path_exists.return_value = True

        # call
        pre_build.main()

        # assert
        syntho_charts_dir = os.path.abspath(os.path.join("cli", "scripts", "syntho-charts"))
        mock_makedirs.assert_called_once_with(syntho_charts_dir, exist_ok=True)

        mock_remove.assert_called_once_with(syntho_charts_dir + ".tar.gz")

        mock_copytree.assert_any_call(
            os.path.abspath("../docker-compose"), os.path.join(syntho_charts_dir, "docker-compose")
        )
        mock_copytree.assert_any_call(os.path.abspath("../helm"), os.path.join(syntho_charts_dir, "helm"))

        mock_open.assert_called_once_with(syntho_charts_dir + ".tar.gz", "w:gz")

        mock_rmtree.assert_called_once_with(syntho_charts_dir)

        mock_tar_add.assert_called_once_with(syntho_charts_dir, arcname="syntho-charts")
