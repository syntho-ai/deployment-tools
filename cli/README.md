# syntho-cli

For detailed information on the CLI's usage, please refer to the [relevant section in the documentation](https://github.com/syntho-ai/deployment-tools/blob/main/cli/docs/getting-started.md).

## For Developers

### Pre-requirements

- Python `3.11.*` (hint: pyenv)
- Poetry (`pip install poetry`)


### Setting up the project

- `poetry install`

### Usage

#### Development Mode

- `poetry run poetry shell`

#### CLI mode - DEV

- Option 1: `poetry run poetry run syntho-cli --help`
- Option 2: `poetry run poetry shell` && `syntho-cli --help`

#### CLI Mode - PROD

- `poetry run poetry build` -> this will create wheels under ./dist
- `pip install ./dist/cli-<VERSION>.tar.gz`

### Running tests

- Unit tests: `pytest tests/`
- Integration tests: `cd ./tests/integration && ./run.sh`
