# syntho-cli

For detailed information on the CLI's usage, please refer to the [relevant section in the documentation](https://github.com/syntho-ai/deployment-tools/blob/main/cli/docs/getting-started.md).

## For Developers

### Pre-requirements

- Python `3.12.*` (hint: pyenv)
- Poetry (`pip install poetry`)


### Setting up the project

- `poetry install`

### Usage

#### Development Mode

- `poetry run pre-build && poetry shell`

#### CLI mode - DEV

- Option 1: `poetry run pre-build && poetry run syntho-cli --help`
- Option 2: `poetry run pre-build && poetry shell` && `syntho-cli --help`

#### CLI Mode - PROD

- `poetry run pre-build && poetry build` -> this will create wheels under ./dist
- `pip install ./dist/cli-<VERSION>.tar.gz`
