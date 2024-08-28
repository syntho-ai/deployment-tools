from unittest import TestCase, mock

from cli.dynamic_configuration.predefined_funcs import (
    concatenate,
    divide,
    kubectlget,
    lowercase,
    onlythesevalues,
    regex,
    returnasis,
)
from cli.utils import SubprocessResult


class TestRegex(TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def validate(self, pattern, valid_inputs, invalid_inputs):
        for valid_input in valid_inputs:
            exc = None
            try:
                regex("test-dir", pattern, valid_input)
            except Exception as e:
                exc = e

            self.assertTrue(exc is None, f"Valid input '{valid_input}' failed the regex test")

        for invalid_input in invalid_inputs:
            exc = None
            try:
                regex("test-dir", pattern, invalid_input)
            except Exception as e:
                exc = e

            self.assertTrue(exc is not None, f"Invalid input '{invalid_input}' passed the regex test")

    def test_only_y_and_n(self):
        pattern = "^[yYnN]$"
        valid_inputs = ["y", "Y", "n", "N"]
        invalid_inputs = ["1", "yes", "no"]

        self.validate(pattern, valid_inputs, invalid_inputs)

    def test_any_input(self):
        pattern = ".+"
        valid_inputs = ["any", "random", "1000", "storage-class"]

        self.validate(pattern, valid_inputs, [])

    def test_schema(self):
        pattern = "^[Hh][Tt][Tt][Pp]([Ss])?$"
        valid_inputs = ["http", "HTTP", "https", "HTTPS"]
        invalid_inputs = ["1", "yes", "no", "cancel", "htt", "HTPS"]

        self.validate(pattern, valid_inputs, invalid_inputs)

    def test_divisible_by_1000(self):
        pattern = "^[1-9][0-9]*000$"
        valid_inputs = ["1000", "2000", "4000", "10000"]
        invalid_inputs = ["750", "1250", "9999", "foobar"]

        self.validate(pattern, valid_inputs, invalid_inputs)

    def test_divisible_by_4(self):
        pattern = "^.*([048]|([02468][048])|([13579][26]))$"
        valid_inputs = ["4", "8", "32", "128"]
        invalid_inputs = ["2", "6", "9", "1001"]

        self.validate(pattern, valid_inputs, invalid_inputs)

    def test_email(self):
        pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        valid_inputs = ["foo@bar.com"]
        invalid_inputs = ["any", "1000", "foobar.com"]

        self.validate(pattern, valid_inputs, invalid_inputs)

    def validate_password(self):
        pattern = "^.{8,}$"
        valid_inputs = ["12345678"]
        invalid_inputs = ["1234567"]

        self.validate(pattern, valid_inputs, invalid_inputs)


def test_lowercase():
    inp = "CamelCase"
    out = "camelcase"

    assert lowercase("test-dir", inp) == out


def test_returnasis():
    inp = "foobar"
    out = "foobar"

    assert returnasis("test-dir", inp) == out


def test_concatenate():
    args = ["this", "is", 1, "foo", "bar"]
    out = "thisis1foobar"

    assert concatenate("test-dir", *args) == out


class TestDivide(TestCase):
    def test_divide(self):
        self.assertTrue(divide("test-dir", 4, 2) == 2)
        self.assertTrue(divide("test-dir", 100, 25) == 4)

    def test_divide_conversion_error(self):
        with self.assertRaises(ValueError) as context:
            divide("test-dir", "string", 2)
        self.assertTrue("Conversion error" in str(context.exception))

    def test_divide_by_zero(self):
        with self.assertRaises(ValueError) as context:
            divide("test-dir", 10, 0)
        self.assertTrue("The divisor cannot be zero." in str(context.exception))


def test_kubectlget():
    with (
        mock.patch("cli.dynamic_configuration.predefined_funcs.run_script") as mock_run_script,
    ):
        mock_run_script.return_value = SubprocessResult(succeeded=True, output="local-path", exitcode=0)
        deployment_dir = "foo/bar/scripts/deployments/a-deployment-id"
        args = ["get", "pv", "-l", "pv-label-key=mylabel", "-o", 'jsonpath="{.items[*].spec.storageClassName}"']
        value = kubectlget(deployment_dir, *args)

        assert value == "local-path"

        mock_run_script.assert_called_with(
            "foo/bar/scripts",
            "foo/bar/scripts/deployments/a-deployment-id",
            "kubectlget.sh",
            capture_output=True,
            **{"PARAMS": 'get pv -l pv-label-key=mylabel -o jsonpath="{.items[*].spec.storageClassName}"'},
        )


class TestOnlyTheseValues(TestCase):
    def validate(self, given_value, allowed_values, should_raise):
        exc = None
        try:
            result = onlythesevalues("test-dir", given_value, allowed_values)
        except Exception as e:
            exc = e

        if should_raise:
            self.assertTrue(exc is not None, f"Invalid input '{given_value}' passed the validation")
        else:
            self.assertTrue(exc is None, f"Valid input '{given_value}' failed the validation")
            self.assertTrue(result, f"Valid input '{given_value}' did not return True")

    def test_valid_values(self):
        allowed_values = "1,2,3"
        valid_inputs = ["1", "2", "3"]

        for valid_input in valid_inputs:
            self.validate(valid_input, allowed_values, should_raise=False)

    def test_invalid_values(self):
        allowed_values = "1,2,3"
        invalid_inputs = ["4", "5", "a", ""]

        for invalid_input in invalid_inputs:
            self.validate(invalid_input, allowed_values, should_raise=True)
