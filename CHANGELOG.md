## syntho-cli-1.21.0 (2024-07-12)

### Feat

- dynamic configuration schema update
- rolling back tag pattern match
- validates given version when installing to docker and kubernetes
- adds a new cli command to list syntho application versions
- questions validations now uses schema from syntho-cli lib
- rolling tags match pattern back to see if release-ci is triggered
- adds questions schema logic under cli

### Fix

- fix tag creation for Syntho CLI release
- sigh
- question params for kubectlget

## 1.28.0 (2024-06-26)

### Feat

- Implements predefined funcs for them to be defined in dynamic configuration questions (#16)
- implements dynamic configurations pattern and their validation logic (#13)
- implements --dry-run functionality for deployments
- **cli**: Add shell check support.

### Fix

- fix version of dynamic-configuration
- update backend healthcheck endpoint (#12)
- Fix issues with secrets for Backend (#15)
- adjust pvlabel to be different for Ray data storage
- add ray data storage for shared storage among ray nodes
- fix debug statement in CI
- set correct path for publishing to pypi
- specifically set directory for twine
- set content to read for release pipeline CLI
- fix pipeline for releasing CLI
- fix input when calling get_version (#5)
- fix poetry
- support python 3.11 and higher
- fix version command and update links
- fix version
- fix package name during poetry build
- fix typo
- test PyPI token
- change to PAT token to trigger actions
- fixing syntho-cli upload pipeline by removing if statement
- mostly testing whether pipeline gets triggered correctly
- fix release and bump version pipelines
- Commitizen release pipeline (#4)
- create pyproject, update pre-commit and updates due to running new linting/pre-commit tools
