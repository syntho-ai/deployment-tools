from collections import namedtuple
from enum import Enum
from unittest import TestCase, mock

from cli.dynamic_configuration.core import (
    dump_envs,
    enrich_envs,
    find_question_by_id,
    make_envs,
    make_exposed_mapping,
    proceed_with_questions,
    update_envs,
)

Question = namedtuple("Question", ["id"])
Env = namedtuple("Env", ["name", "default"])
EnvConfiguration = namedtuple("EnvConfiguration", ["scope", "envs"])


class TestFindQuestionById(TestCase):
    def setUp(self):
        self.questions = [Question(id="1"), Question(id="2"), Question(id="3")]

    def test_find_question_by_id(self):
        question = find_question_by_id(self.questions, "2")
        self.assertEqual(question.id, "2")

    def test_find_question_by_id_not_found(self):
        question = find_question_by_id(self.questions, "4")
        self.assertIsNone(question)


class EnvConfigurationScopeEnum(Enum):
    field_config_env = ".config.env"
    field_resources_env = ".resources.env"
    field_auth_env = ".auth.env"
    field_pre_deployment_ops_env = ".pre.deployment.ops.env"
    runtime = "runtime"


class TestMakeEnvs(TestCase):
    def setUp(self):
        self.envs_configuration = [
            EnvConfiguration(
                scope=EnvConfigurationScopeEnum.field_config_env,
                envs=[Env(name="ENV1", default="default1"), Env(name="ENV2", default="default2")],
            ),
            EnvConfiguration(
                scope=EnvConfigurationScopeEnum.runtime,
                envs=[Env(name="ENV3", default="default3"), Env(name="ENV4", default="default4")],
            ),
        ]

    def test_make_envs(self):
        envs = make_envs(self.envs_configuration)
        self.assertEqual(
            envs,
            {
                ".config.env": [{"name": "ENV1", "value": "default1"}, {"name": "ENV2", "value": "default2"}],
                "runtime": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
            },
        )


class TestUpdateEnvs(TestCase):
    def setUp(self):
        self.all_envs = {
            ".config.env": [{"name": "ENV1", "value": "default1"}, {"name": "ENV2", "value": "default2"}],
            "runtime": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        self.all_exposed = [{"name": "ENV1", "value": "exposed1"}, {"name": "ENV3", "value": "exposed3"}]
        self.scope_envs = []

    def test_update_envs(self):
        updated_envs = update_envs(self.all_envs, self.all_exposed, self.scope_envs)
        self.assertEqual(
            updated_envs,
            {
                ".config.env": [{"name": "ENV1", "value": "exposed1"}, {"name": "ENV2", "value": "default2"}],
                "runtime": [{"name": "ENV3", "value": "exposed3"}, {"name": "ENV4", "value": "default4"}],
            },
        )


class TestMakeExposedMapping(TestCase):
    def setUp(self):
        self.all_exposed = [{"name": "ENV1", "value": "exposed1"}, {"name": "ENV2", "value": "exposed2"}]

    def test_make_exposed_mapping(self):
        mapping = make_exposed_mapping(self.all_exposed)
        self.assertEqual(mapping, {"ENV1": "exposed1", "ENV2": "exposed2"})


class TestEnrichEnvs(TestCase):
    def setUp(self):
        self.envs = {
            ".config.env": [{"name": "ENV1", "value": "default1"}, {"name": "ENV2", "value": "default2"}],
            ".pre.deployment.ops.env": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        self.license_key = "test_license_key"
        self.registry_user = "test_registry_user"
        self.registry_pwd = "test_registry_pwd"

    def test_enrich_envs(self):
        enriched_envs = enrich_envs(self.envs, self.license_key, self.registry_user, self.registry_pwd)
        self.assertEqual(
            enriched_envs,
            {
                ".config.env": [
                    {"name": "ENV1", "value": "default1"},
                    {"name": "ENV2", "value": "default2"},
                    {"name": "LICENSE_KEY", "value": "test_license_key"},
                ],
                ".pre.deployment.ops.env": [
                    {"name": "ENV3", "value": "default3"},
                    {"name": "ENV4", "value": "default4"},
                    {"name": "REGISTRY_USER", "value": "test_registry_user"},
                    {"name": "REGISTRY_PWD", "value": "test_registry_pwd"},
                ],
            },
        )


class TestDumpEnvs(TestCase):
    def setUp(self):
        self.all_envs = {
            ".config.env": [{"name": "ENV1", "value": "default1"}, {"name": "ENV2", "value": "default2"}],
            ".pre.deployment.ops.env": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        self.deployment_dir = "/path/to/deployment_dir"

    @mock.patch("cli.dynamic_configuration.core.make_exposed_mapping")
    @mock.patch("builtins.open", new_callable=mock.mock_open)
    def test_dump_envs(self, mock_open, mock_make_exposed_mapping):
        mock_make_exposed_mapping.side_effect = lambda x: {item["name"]: item["value"] for item in x}

        dump_envs(self.all_envs, self.deployment_dir)

        mock_make_exposed_mapping.assert_any_call(self.all_envs[".config.env"])
        mock_make_exposed_mapping.assert_any_call(self.all_envs[".pre.deployment.ops.env"])
        mock_open.assert_any_call(f"{self.deployment_dir}/.config.env", "w")
        mock_open.assert_any_call(f"{self.deployment_dir}/.pre.deployment.ops.env", "w")


class TestProceedWithQuestions(TestCase):
    def setUp(self):
        self.deployment_dir = "/path/to/deployment_dir"
        self.all_envs = {
            ".config.env": [{"name": "ENV1", "value": "default1"}, {"name": "ENV2", "value": "default2"}],
            ".pre.deployment.ops.env": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        self.questions = [
            {
                "id": "1",
                "question": "Question 1",
                "var": "var1",
                "default": "default1",
                "validation": [],
                "post_processing": [],
                "next": None,
            },
            {
                "id": "2",
                "question": "Question 2",
                "var": "var2",
                "default": "default2",
                "validation": [],
                "post_processing": [],
                "next": None,
            },
            {
                "id": "3",
                "question": "Question 3",
                "var": "var3",
                "default": "default3",
                "validation": [],
                "post_processing": [],
                "next": None,
            },
        ]
        self.entrypoint_id = "1"

    @mock.patch("cli.dynamic_configuration.core.find_question_by_id")
    @mock.patch("cli.dynamic_configuration.core.ask_question")
    @mock.patch("cli.dynamic_configuration.core.next_question")
    @mock.patch("cli.dynamic_configuration.core.update_envs")
    def test_proceed_with_questions_exit(
        self, mock_update_envs, mock_next_question, mock_ask_question, mock_find_question_by_id
    ):
        mock_find_question_by_id.return_value = self.questions[0]
        mock_ask_question.return_value = ({"name": "ENV1", "value": "answered1"}, False)
        mock_next_question.return_value = ("2", "exit", [{"name": "ENV1", "value": "answered1"}])
        mock_update_envs.return_value = self.all_envs

        envs, interrupted = proceed_with_questions(
            self.deployment_dir, self.all_envs, self.questions, self.entrypoint_id
        )

        mock_find_question_by_id.assert_called_with(self.questions, "1")
        mock_ask_question.assert_called_with(
            self.deployment_dir,
            self.questions[0],
            with_previous_answer=None,
        )
        mock_next_question.assert_called_with(
            self.deployment_dir, self.questions, self.questions[0], {"name": "ENV1", "value": "answered1"}
        )
        self.assertEqual(envs, self.all_envs)
        self.assertTrue(interrupted)

    @mock.patch("cli.dynamic_configuration.core.find_question_by_id")
    @mock.patch("cli.dynamic_configuration.core.ask_question")
    @mock.patch("cli.dynamic_configuration.core.next_question")
    @mock.patch("cli.dynamic_configuration.core.update_envs")
    def test_proceed_with_questions_complete(
        self, mock_update_envs, mock_next_question, mock_ask_question, mock_find_question_by_id
    ):
        mock_find_question_by_id.return_value = self.questions[0]
        mock_ask_question.return_value = ({"name": "ENV1", "value": "answered1"}, False)
        mock_next_question.return_value = ("2", "complete", [{"name": "ENV1", "value": "answered1"}])

        updated_envs = {
            ".config.env": [{"name": "ENV1", "value": "answered1"}, {"name": "ENV2", "value": "default2"}],
            ".pre.deployment.ops.env": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        mock_update_envs.return_value = updated_envs

        envs, interrupted = proceed_with_questions(
            self.deployment_dir, self.all_envs, self.questions, self.entrypoint_id
        )

        mock_find_question_by_id.assert_called_with(self.questions, "1")
        mock_ask_question.assert_called_with(
            self.deployment_dir,
            self.questions[0],
            with_previous_answer=None,
        )
        mock_next_question.assert_called_with(
            self.deployment_dir,
            self.questions,
            self.questions[0],
            {"name": "ENV1", "value": "answered1"},
        )
        mock_update_envs.assert_called_with(
            self.all_envs, [{"name": "ENV1", "value": "answered1"}], [{"name": "ENV1", "value": "answered1"}]
        )
        self.assertEqual(envs, updated_envs)
        self.assertFalse(interrupted)

    @mock.patch("cli.dynamic_configuration.core.find_question_by_id")
    @mock.patch("cli.dynamic_configuration.core.ask_question")
    @mock.patch("cli.dynamic_configuration.core.next_question")
    @mock.patch("cli.dynamic_configuration.core.update_envs")
    def test_proceed_with_questions_proceed_then_complete(
        self, mock_update_envs, mock_next_question, mock_ask_question, mock_find_question_by_id
    ):
        mock_find_question_by_id.side_effect = [self.questions[0], self.questions[1]]
        mock_ask_question.side_effect = [
            (self.all_envs[".config.env"][0], False),
            (self.all_envs[".config.env"][1], False),
        ]
        mock_next_question.side_effect = [
            ("2", "proceed", [{"name": "ENV1", "value": "answered1"}]),
            ("3", "complete", [{"name": "ENV2", "value": "answered2"}]),
        ]

        updated_envs = {
            ".config.env": [{"name": "ENV1", "value": "answered1"}, {"name": "ENV2", "value": "answered2"}],
            ".pre.deployment.ops.env": [{"name": "ENV3", "value": "default3"}, {"name": "ENV4", "value": "default4"}],
        }
        mock_update_envs.return_value = updated_envs

        envs, interrupted = proceed_with_questions(
            self.deployment_dir, self.all_envs, self.questions, self.entrypoint_id
        )

        self.assertEqual(
            mock_find_question_by_id.call_args_list, [mock.call(self.questions, "1"), mock.call(self.questions, "2")]
        )
        self.assertEqual(
            mock_ask_question.call_args_list,
            [
                mock.call(self.deployment_dir, self.questions[0], with_previous_answer=None),
                mock.call(self.deployment_dir, self.questions[1], with_previous_answer=None),
            ],
        )
        self.assertEqual(
            mock_next_question.call_args_list,
            [
                mock.call(self.deployment_dir, self.questions, self.questions[0], self.all_envs[".config.env"][0]),
                mock.call(self.deployment_dir, self.questions, self.questions[1], self.all_envs[".config.env"][1]),
            ],
        )
        mock_update_envs.assert_called_with(
            self.all_envs,
            [{"name": "ENV1", "value": "answered1"}, {"name": "ENV2", "value": "answered2"}],
            [self.all_envs[".config.env"][0], self.all_envs[".config.env"][1]],
        )
        self.assertEqual(envs, updated_envs)
        self.assertFalse(interrupted)
