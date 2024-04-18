# tests/test_utils.py
import os
import fcntl
import subprocess

import unittest
from unittest.mock import patch, MagicMock, mock_open

from cli.utils import (CURSOR_TRACKER, reset_cursor_tracker, is_arch_supported, thread_safe,
                       with_working_directory, get_deployments_dir, run_script, tail,
                       deployment_exists, utility_exists, make_utilities_dir,
                       generate_utilities_dir, check_acquired, acquire, release, set_status,
                       find_available_port, make_tarfile, get_architecture)


def test_reset_cursor_tracker():
    # Initial cursor tracker should be empty
    assert not CURSOR_TRACKER

    # Call reset_cursor_tracker with a deployment ID
    reset_cursor_tracker("deployment_1")

    # Cursor tracker should contain the deployment ID
    assert "deployment_1" in CURSOR_TRACKER
    # The cursor for this deployment should be reset
    assert CURSOR_TRACKER["deployment_1"] == {}


# Test is_arch_supported function

def test_is_arch_supported():
    # Test with supported architectures
    assert is_arch_supported("amd") is True
    assert is_arch_supported("arm") is True

    # Test with unsupported architectures
    assert is_arch_supported("unknown") is False
    assert is_arch_supported("sparc") is False


# Mock functions for testing
def mock_func(*args, **kwargs):
    return "Mock function executed"


@thread_safe
def mock_thread_safe_func(*args, **kwargs):
    return "Thread-safe mock function executed"


def test_thread_safe():
    # Test normal behavior without the decorator
    assert mock_func() == "Mock function executed"

    # Test behavior with the decorator
    assert mock_thread_safe_func() == "Thread-safe mock function executed"

    # Test that the lock file is created
    assert os.path.exists("/tmp/.lock")

    # Test that the lock is acquired and released properly
    lock_acquired = False
    with open("/tmp/.lock", "r") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            lock_acquired = True
        except BlockingIOError:
            lock_acquired = False

    assert lock_acquired is True

    # Test that the lock is released after execution
    lock_released = False
    try:
        with open("/tmp/.lock", "r") as lock_file:
            fcntl.flock(lock_file, fcntl.LOCK_UN)  # Release the lock
            lock_released = True
    except BlockingIOError:
        lock_released = False

    assert lock_released is True


def test_with_working_directory():
    # Define a mock function that changes the working directory
    def mock_function():
        return os.getcwd()

    # Define a function to be decorated
    @with_working_directory
    def decorated_function():
        return os.getcwd()

    # Call the mock function to get the current directory before applying the decorator
    original_directory = mock_function()

    # Call the decorated function
    decorated_directory = decorated_function()

    # Assert that the decorated function returns to the original directory after execution
    assert decorated_directory == original_directory


def test_get_deployments_dir(tmpdir):
    # Create a temporary directory for testing
    temp_dir = tmpdir.mkdir("test_dir")

    # Define the script directory
    scripts_dir = str(temp_dir)

    # Call the function under test
    deployments_dir = get_deployments_dir(scripts_dir)

    # Assert that the deployments directory is created
    assert os.path.exists(deployments_dir)

    # Assert that the deployments directory path is correct
    assert deployments_dir == f"{scripts_dir}/deployments"

    # Remove the deployments directory
    os.rmdir(deployments_dir)


def test_run_script():
    # Define a test scripts directory
    scripts_dir = "/path/to/scripts"

    # Define a test deployment directory
    deployment_dir = "/path/to/deployment"

    # Define a test script name
    script_name = "test_script.sh"

    # Define the expected output of the mock subprocess
    expected_output = "Hello, world!"

    # Mock subprocess.run() to return a predefined result
    with patch("subprocess.run") as mock_subprocess_run:
        # Define the mock return value
        mock_subprocess_run.return_value = subprocess.CompletedProcess(
            args=[script_name],
            returncode=0,
            stdout=expected_output.encode(),
            stderr=b"",
        )

        # Call the function under test
        result = run_script(scripts_dir, deployment_dir, script_name, capture_output=True)

        # Assert that subprocess.run() was called with the correct arguments
        mock_subprocess_run.assert_called_once_with(
            [os.path.join(scripts_dir, script_name)],
            check=True,
            shell=False,
            env={"DEPLOYMENT_DIR": deployment_dir, "PATH": os.environ.get("PATH", "")},
            capture_output=True,
            text=True,
        )

        # Assert that the result matches the expected output
        assert result.succeeded is True
        assert result.output.decode() == expected_output
        assert result.exitcode == 0


class TestTailFunction(unittest.TestCase):
    @patch("subprocess.Popen")
    @patch("cli.utils.read_lines")
    def test_tail_function(self, mock_read_lines, mock_popen):
        # Mock the subprocess.Popen instance
        mock_proc = MagicMock()
        mock_proc.stdout = MagicMock()
        mock_popen.return_value = mock_proc

        # Mock the behavior of read_lines
        mock_read_lines.return_value = [b"line1\n", b"line2\n", b"line3\n"]

        # Call the function
        tail("filename.log", 10, True, "deployment_id")

        # Check if subprocess.Popen was called with the correct arguments
        mock_popen.assert_called_once_with(["tail", "-F", "-n", "10", "filename.log"],
                                           stdout=subprocess.PIPE)

        # Check if read_lines was called
        mock_read_lines.assert_called_once_with(mock_proc.stdout, 5)


class TestDeploymentExists(unittest.TestCase):
    @patch("os.path.isdir")
    def test_deployment_exists(self, mock_isdir):
        # Mock the os.path.isdir function
        mock_isdir.return_value = True

        # Call the function with a mocked scripts_dir and deployment_id
        result = deployment_exists("/mocked_scripts_dir", "mocked_deployment_id")

        # Check if os.path.isdir was called with the correct arguments
        mock_isdir.assert_called_once_with("/mocked_scripts_dir/deployments/mocked_deployment_id")

        # Check if the function returned True
        self.assertTrue(result)


class TestUtilityExists(unittest.TestCase):
    @patch("os.path.isdir")
    def test_utility_exists(self, mock_isdir):
        # Mock the os.path.isdir function
        mock_isdir.return_value = True

        # Call the function with mocked scripts_dir and utility_name
        result = utility_exists("/mocked_scripts_dir", "mocked_utility_name")

        # Check if os.path.isdir was called with the correct arguments
        mock_isdir.assert_called_once_with("/mocked_scripts_dir/utilities/mocked_utility_name")

        # Check if the function returned True
        self.assertTrue(result)


class TestMakeUtilitiesDir(unittest.TestCase):
    @patch("os.path.exists")
    @patch("os.makedirs")
    def test_make_utilities_dir(self, mock_makedirs, mock_exists):
        # Mock the os.path.exists function to return False
        mock_exists.return_value = False

        # Call the function
        make_utilities_dir("/mocked_scripts_dir")

        # Check if os.path.exists was called with the correct arguments
        mock_exists.assert_called_once_with("/mocked_scripts_dir/utilities")

        # Check if os.makedirs was called with the correct arguments
        mock_makedirs.assert_called_once_with("/mocked_scripts_dir/utilities")


def test_generate_utilities_dir():
    # Define the input scripts_dir
    scripts_dir = "/mocked_scripts_dir"

    # Call the function
    result = generate_utilities_dir(scripts_dir)

    # Check if the result is correct
    expected_result = "/mocked_scripts_dir/utilities"
    assert result == expected_result


class TestCheckAcquired(unittest.TestCase):
    @patch("os.path.exists")
    def test_check_acquired(self, mock_exists):
        # Mock the return value of os.path.exists to simulate the presence of the lock file
        mock_exists.return_value = True

        # Call the function with a mocked file directory
        result = check_acquired("mocked_directory")

        # Assert that the result is True since the lock file exists
        self.assertTrue(result)


class TestAcquireRelease(unittest.TestCase):
    @patch("builtins.open", new_callable=mock_open)
    def test_acquire(self, mock_open):
        # Mock the open function to simulate opening a file
        acquire("mocked_directory")

        # Assert that open is called with the correct file path and mode
        mock_open.assert_called_once_with("mocked_directory/.lock", "a")

    @patch("os.remove")
    def test_release(self, mock_remove):
        # Call the release function
        release("mocked_directory")

        # Assert that os.remove is called with the correct file path
        mock_remove.assert_called_once_with("mocked_directory/.lock")


class TestSetStatus(unittest.TestCase):
    @patch("builtins.open", new_callable=mock_open)
    def test_set_status(self, mock_open):
        # Call the set_status function
        set_status("mocked_directory", "mocked_status")

        # Assert that open is called with the correct file path and mode
        mock_open.assert_called_once_with("mocked_directory/status", "w")

        # Assert that write is called with the correct status
        mock_open.return_value.write.assert_called_once_with("mocked_status")


class TestFindAvailablePort(unittest.TestCase):
    @patch("cli.utils.check_port")
    def test_find_available_port(self, mock_check_port):
        # Set up the mock check_port function
        def mock_check_port_side_effect(host, port):
            # Return True for ports 8080 and 8081, False otherwise
            if port in [8080, 8081]:
                return False
            else:
                return True
        mock_check_port.side_effect = mock_check_port_side_effect

        host = "localhost"
        # Call the function
        result = find_available_port(8080, 8085, host=host)

        # Check that check_port was called with the correct arguments
        self.assertEqual(len(mock_check_port.call_args_list), 3)

        # Check that the result is as expected
        self.assertEqual(result, 8082)  # Assuming 8082 is the first available port


class TestMakeTarfile(unittest.TestCase):
    @patch("cli.utils.tarfile.open")
    def test_make_tarfile(self, mock_tarfile_open):
        # Call the function
        make_tarfile("output.tar.gz", "/path/to/source")

        # Check that tarfile.open was called with the correct arguments
        mock_tarfile_open.assert_called_once_with("output.tar.gz", "w:gz")

        # Check that the tarfile.add method was called with the correct arguments
        mock_tarfile_instance = mock_tarfile_open.return_value.__enter__.return_value
        mock_tarfile_instance.add.assert_called_once_with("/path/to/source", arcname="source")


class TestGetArchitecture(unittest.TestCase):
    def test_get_architecture(self):
        # Define test cases with various architecture information
        test_cases = [
            ("x86_64", "amd"),  # Test case for x86_64 architecture
            ("arm64", "arm"),   # Test case for arm64 architecture
            ("aarch64", "arm"),  # Test case for aarch64 architecture
            ("ppc64le", "ppc64le"),  # Test case for ppc64le architecture
            ("sparc64", "sparc64"),  # Test case for sparc64 architecture
            ("unknown", "unknown"),  # Test case for unknown architecture
        ]

        # Iterate through test cases
        for arch_info, expected_result in test_cases:
            # Mock platform.machine to return the architecture information
            with unittest.mock.patch("platform.machine", return_value=arch_info):
                # Call the get_architecture function
                result = get_architecture()

                # Assert that the result matches the expected result
                self.assertEqual(result, expected_result)
