import logging
import sys

import yaml
from jsonschema import Draft7Validator

from .schema.question_schema import QuestionSchema

logger = logging.getLogger(__name__)

schema = yaml.safe_load(open("./src/questions-schema.yaml", "r"))


def load_yaml_file(filename):
    with open(filename, "r") as file:
        try:
            return yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(exc)
            return None


def validate_yaml(yaml_data, schema):
    validator = Draft7Validator(schema)
    errors = list(validator.iter_errors(yaml_data))
    if errors:
        for error in errors:
            print(format_error_message(error))
        sys.exit(1)
    else:
        print("Schema validation is successful. The configuration YAML file is valid.")
        check_paths(yaml_data)


def validate_yaml_pydantic(yaml_data):
    try:
        QuestionSchema.model_validate(yaml_data)
        print("Schema validation is successful. The configuration YAML file is valid.")
        check_paths(yaml_data)
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


def format_error_message(error):
    path = ".".join(str(p) for p in error.path)
    return f"Error at path '{path}': {error.message}"


def check_paths(yaml_data):
    questions = {q["id"]: q for q in yaml_data["questions"]}
    entrypoint = yaml_data["entrypoint"]

    def traverse(question_id, visited):
        if question_id in visited:
            print(f"question_id '{question_id}' is not visited")
            return False
        visited.add(question_id)

        if question_id not in questions:
            print(f"question_id '{question_id}' doesn't exist")
            return False

        question = questions[question_id]
        next_steps = question.get("next", {}).get("conditions", [])

        for step in next_steps:
            if step["question_id"] is None:
                if step["action"] == "exit" or step["action"] == "complete":
                    continue
                else:
                    print(
                        f"question_id for next in '{question_id}' is null, and action is neither "
                        "exit or complete. Therefore there is no place to go from here."
                    )
                    return False
            elif not traverse(step["question_id"], visited.copy()):
                return False

        return True

    if traverse(entrypoint, set()):
        print("All paths in questions are valid.")
    else:
        print("Found dead ends in the paths.")
        sys.exit(1)


def main():
    question_files = [
        "./src/k8s_questions.yaml",
        "./src/dc_questions.yaml",
    ]
    for question_file in question_files:
        print(f"[Validation for {question_file}]")
        yaml_data = load_yaml_file(question_file)
        if yaml_data:
            validate_yaml_pydantic(yaml_data)
        print("\n")


if __name__ == "__main__":
    main()
