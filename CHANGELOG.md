## 1.18.0 (2024-07-03)

### Feat

- validates given version when installing to docker and kubernetes

## 1.17.0 (2024-07-03)

### Feat

- adds a new cli command to list syntho application versions

## 1.16.0 (2024-07-01)

### Feat

- questions validations now uses schema from syntho-cli lib

## 1.15.0 (2024-07-01)

### Feat

- rolling tags match pattern back to see if release-ci is triggered

## 1.14.0 (2024-07-01)

### Feat

- adds questions schema logic under cli

## 1.28.0 (2024-06-26)

## 1.13.0 (2024-06-24)

### Feat

- Implements predefined funcs for them to be defined in dynamic configuration questions (#16)

## 1.12.0 (2024-06-24)

### Feat

- implements dynamic configurations pattern and their validation logic (#13)

### Fix

- fix version of dynamic-configuration

## 1.11.3 (2024-06-24)

### Fix

- update backend healthcheck endpoint (#12)

## 1.11.2 (2024-06-24)

### Fix

- Fix issues with secrets for Backend (#15)

## 1.11.1 (2024-05-28)

### Fix

- adjust pvlabel to be different for Ray data storage
- add ray data storage for shared storage among ray nodes

## 1.11.0 (2024-05-23)

### Feat

- implements --dry-run functionality for deployments

## 1.10.16 (2024-05-14)

### Fix

- fix debug statement in CI

## 1.10.15 (2024-05-14)

### Fix

- set correct path for publishing to pypi

## 1.10.14 (2024-05-14)

### Fix

- specifically set directory for twine

## 1.10.13 (2024-05-14)

### Fix

- set content to read for release pipeline CLI

## 1.10.12 (2024-05-14)

### Fix

- fix pipeline for releasing CLI

## 1.10.11 (2024-05-13)

### Fix

- fix input when calling get_version (#5)

## 1.10.10 (2024-05-08)

### Fix

- fix poetry

## 1.10.9 (2024-05-08)

### Fix

- support python 3.11 and higher

## 1.10.8 (2024-05-08)

### Fix

- fix version command and update links

## 1.10.7 (2024-05-08)

### Fix

- fix version
- fix package name during poetry build

## 1.10.6 (2024-05-08)

### Fix

- fix typo

## 1.10.5 (2024-05-08)

### Fix

- test PyPI token

## 1.10.4 (2024-05-08)

### Fix

- change to PAT token to trigger actions

## 1.10.3 (2024-05-08)

### Fix

- fixing syntho-cli upload pipeline by removing if statement

## 1.10.2 (2024-05-08)

### Fix

- mostly testing whether pipeline gets triggered correctly

## 1.10.1 (2024-05-08)

### Fix

- fix release and bump version pipelines

## 1.10.0 (2024-05-08)

### Feat

- **cli**: Add shell check support.

### Fix

- Commitizen release pipeline (#4)
- create pyproject, update pre-commit and updates due to running new linting/pre-commit tools
