.PHONY: tests coverage-report

tests:
	@pytest

coverage-report:
	@coverage run -m unittest discover -s tests && \
	coverage report --omit="tests/*"

generate-questions-schema:
	@echo "Generating code from JSON schema"
	poetry run generate-questions-schema
	datamodel-codegen --input cli/dynamic_configuration/schema/questions-schema.json --input-file-type jsonschema --output cli/dynamic_configuration/schema/question_schema.py
