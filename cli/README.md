# syntho-cli

For detailed information on this topic, please refer to the [relevant section in the documentation](https://github.com/syntho-ai/syntho-cli/blob/main/docs/getting-started.md).

## For Developers

Developers can approach this project with two different ways, as production code doesn't need some
testing/linting/formatting libraries in place

1. Development Mode
2. Playing Mode


### Development Mode

When developing the CLI

> A virtual env is recommended.

```
pip install -r requirements-dev.txt
```

#### Enabling pre-commit hooks

pre-commit ensures that our code adheres to specific quality standards, enhancing the overall
quality and maintainability of our projects.
Please ensure that you have pre-commit installed to benefit from these automated checks.

```
pre-commit install
```

### Playing Mode

When testing the CLI locally

> A virtual env is recommended.

```
make pip-local-install
```
