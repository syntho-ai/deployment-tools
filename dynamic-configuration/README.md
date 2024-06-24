# dynamic-configuration

This project is designed to validate dynamic, DAG-like configuration questions for Kubernetes and Docker Compose, utilized in the Syntho CLI to streamline deployments. By decoupling configuration questions from the CLI, this approach allows for seamless extension of configuration scopes. When new environment variables need to be integrated into Helm or Docker Compose, they can be easily added by updating the configuration questions for each deployment type, ensuring flexibility and scalability in managing deployments.

## Pre-requirements

- Python `3.12.*` (hint: pyenv)
- Poetry (`pip install poetry`)

## Setting up the project

- `poetry install`

## Running Validation

```
poetry run validate
```
