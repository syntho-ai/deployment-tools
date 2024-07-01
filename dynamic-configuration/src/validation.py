import argparse
import logging
import sys

import yaml

from cli.dynamic_configuration.schema.question_schema import QuestionSchema

logger = logging.getLogger(__name__)


def load_yaml_file(filename):
    with open(filename, "r") as file:
        try:
            return yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(exc)
            return None


def validate_yaml_pydantic(yaml_data):
    try:
        QuestionSchema.model_validate(yaml_data)
        print("Schema validation is successful. The configuration YAML file is valid.")
        check_paths(yaml_data)
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


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
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dc-questions-path", help="Path to Docker Compose questions YAML file", default="./src/dc_questions.yaml"
    )
    parser.add_argument(
        "--k8s-questions-path", help="Path to Kubernetes questions YAML file", default="./src/k8s_questions.yaml"
    )
    args = parser.parse_args()
    question_files = [args.dc_questions_path, args.k8s_questions_path]
    for question_file in list(question_files):
        print(f"[Validation for {question_file}]")
        yaml_data = load_yaml_file(question_file)
        if yaml_data:
            validate_yaml_pydantic(yaml_data)
        print("\n")


if __name__ == "__main__":
    main()
