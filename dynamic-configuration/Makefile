generate:
	@echo "Generating code from JSON schema"
	poetry run generate-schema
	datamodel-codegen --input src/schema/questions-schema.json --input-file-type jsonschema --output src/schema/question_schema.py
