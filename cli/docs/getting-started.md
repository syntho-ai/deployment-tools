# Getting Started with syntho-cli

## Overview
`syntho-cli` is a powerful command-line tool designed to streamline the deployment of Syntho resources in Docker and Kubernetes environments.
With `syntho-cli`, you can effortlessly deploy, manage, and uninstall a variety of resources, thus simplifying your DevOps workflow.
`syntho-cli` can manage deployments for both locally, and for remote clusters/hosts.

This document provides a quick start guide on how to install and use `syntho-cli`, as well as instructions for uninstallation.

## Installation
To install syntho-cli, please run the following command:

> Before installing the CLI, make sure that `python` and `pip` is installed.

```
pip install syntho-cli
```

Verify the installation by running:

```
syntho-cli --version
```

You should see `syntho-cli, version x.y.z` as the output.

## Usage
`syntho-cli` provides the flexibility to manage resources in both Docker and Kubernetes ecosystems. Follow the guides below based on your specific needs:

### Docker Compose
To learn how to manage resources in a Docker environment with `syntho-cli`, visit the [Docker Compose guide](./docker-compose.md).

### Kubernetes
To learn how to manage resources in a Kubernetes environment with `syntho-cli`, visit the [Kubernetes guide](./kubernetes.md).

## Uninstallation
To uninstall syntho-cli, please run the following command:

> Before uninstalling the `syntho-cli`, [make sure](#usage) there is no active deployment that is managed by the CLI.

```
pip uninstall syntho-cli
```
