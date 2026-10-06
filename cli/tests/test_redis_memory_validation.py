from pathlib import Path
from unittest import mock

import pytest
import yaml

from cli.dynamic_configuration.core import make_envs, proceed_with_questions
from cli.dynamic_configuration.predefined_funcs import redis_memory_limit
from cli.dynamic_configuration.schema.question_schema import ActionEnum, QuestionSchema


@pytest.mark.parametrize(
    ("limit", "maxmemory"),
    [
        ("512Mi", "511mb"),
        ("512m", "511mb"),
        ("512M", "1mb"),
        ("513Mi", "512mb"),
        ("2Gi", "1gb"),
        ("2g", "1gb"),
        ("2G", "1024mb"),
        ("2048m", "1gb"),
    ],
)
def test_valid_redis_memory_limit(limit, maxmemory):
    assert redis_memory_limit("test-dir", limit, maxmemory)


@pytest.mark.parametrize(
    ("limit", "maxmemory"),
    [
        ("1Mi", "1mb"),
        ("511Mi", "1mb"),
        ("511m", "1mb"),
        ("512Mi", "512mb"),
        ("512m", "512mb"),
        ("1Gi", "1gb"),
        ("1g", "1024mb"),
        ("2Gi", "3gb"),
        ("0Mi", "1mb"),
        ("-1g", "1mb"),
        ("1.5Gi", "1mb"),
        ("2Gi\n", "1mb"),
        ("2Gi", "$REDIS_MAXMEMORY"),
        ("2Gi", "invalid"),
    ],
)
def test_invalid_redis_memory_limit(limit, maxmemory):
    with pytest.raises(ValueError):
        redis_memory_limit("test-dir", limit, maxmemory)


@pytest.mark.parametrize("platform", ["dc", "k8s"])
@pytest.mark.parametrize("maxmemory", ["", "1gb"])
def test_redis_questions_reprompt_before_generating_values(platform, maxmemory, capsys):
    questions_path = (
        Path(__file__).resolve().parents[2] / "dynamic-configuration" / "src" / f"{platform}_questions.yaml"
    )
    with questions_path.open() as file:
        schema = QuestionSchema.model_validate(yaml.safe_load(file))
    questions = [question for question in schema.questions if question.id in ("redis_maxmemory", "redis_memory_limit")]
    questions[-1].next.conditions[0].action = ActionEnum.complete
    questions[-1].next.conditions[0].question_id = None
    unit = "m" if platform == "dc" else "Mi"
    equal_limit = f"512{unit}" if not maxmemory else ("1g" if platform == "dc" else "1Gi")
    with mock.patch("builtins.input", side_effect=[maxmemory, f"1{unit}", f"511{unit}", equal_limit, ""]):
        envs, interrupted = proceed_with_questions(
            "test-dir", make_envs(schema.envs_configuration), questions, "redis_maxmemory"
        )

    assert not interrupted
    resources = {env["name"]: env["value"] for env in envs[".resources.env"]}
    assert resources["REDIS_MAXMEMORY"] == (maxmemory or "512mb")
    assert resources["REDIS_MEMORY_LIMIT"] == ("2g" if platform == "dc" else "2Gi")
    assert capsys.readouterr().out.count("must be at least") == 3
