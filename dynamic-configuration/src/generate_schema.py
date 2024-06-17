# generated by datamodel-codegen:
#   filename:  questions-schema.yaml
#   timestamp: 2024-06-17T11:36:56+00:00

from __future__ import annotations

import json
import logging

from src.models import QuestionSchema

logger = logging.getLogger(__name__)


def main():
    schema = QuestionSchema.model_json_schema()

    with open("./src/schema/questions-schema.json", "w") as schema_file:
        json.dump(schema, schema_file)
    logger.info("Schema is generated successfully.")


if __name__ == "__main__":
    main()
