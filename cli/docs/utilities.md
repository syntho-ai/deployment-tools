# Using utilities with syntho-cli

In this guide, we will walk through how to use `syntho-cli` to effectively use utilities functions
to make your life easier.

## Applicable Scenarios

1. the host where docker daemon or kubernetes cluster is located can't access to Syntho's registry
   because of some security reasons
2. the host where docker daemon or kubernetes cluster doesn't have any outbound network access
   because of some security reasons (NOT READY YET)

## Prerequisites

* `syntho-cli` installed ([See Getting Started guide](./getting-started.md))
* A running Docker server
* `docker` cli installed and properly configured
* An active internet connection on the host where the CLI is going to run
* No firewall or any other custom network setup that prevents host to access Syntho's image
  registry (syntho.azurecr.io)
* Other command line utilities: `tar`, `awk`, `curl or wget`,`jq`, `grep`
* The docker node must be of the `amd64` architecture


## Overview

`syntho-cli` has extra utilities to unlock some certain scenarios.

Below are examples of common tasks you might want to perform with `syntho-cli` in the scope of
utilities:

> TL;DR: `syntho-cli utilities --help`

### Pulling Images Into a Trusted Image Registry

As mentioned in [Applicable Scenarios](applicable-scenarios) - scenario 1, below command can be ran
to get necessary images pulled in a trusted image registry.


```
syntho-cli utilities prepull-images \
    --trusted-registry <trusted-registry-url> \
    --syntho-registry-user <syntho-image-registry-user> \
    --syntho-registry-pwd <syntho-image-registry-password> \
    --version <syntho-stack-version> \
    --docker-config <path-to-docker-config-json> # optional - default: ~/.docker/config.json
```

> Ask Syntho team to fetch your credentials and the version for Syntho resources

> This process takes roughly 10 mins as it is going to be pulling and pushing images accordingly.
> When the process is completed, CLI can be ran to deploy Syntho Stack via this trusted image
> registry. Please visit [kubernetes](./kubernetes) or [docker-compose](./docker-compose.md) guide
> for more details.


### Activating Offline Mode

As mentioned in [Applicable Scenarios](applicable-scenarios) - scenario 2, below command can be ran
to enable CLI for deployments to offline ecosystems.


```
syntho-cli utilities activate-offline-mode \
    --syntho-registry-user <syntho-image-registry-user> \
    --syntho-registry-pwd <syntho-image-registry-password> \
    --version <syntho-stack-version>
```

> Ask Syntho team to fetch your credentials and the version for Syntho resources

> This process takes roughly 10 mins as it is going to be pulling and pushing images accordingly.
> When the process is completed, CLI can be ran to deploy Syntho Stack via this offline image
> registry. Please visit [kubernetes](./kubernetes) or [docker-compose](./docker-compose.md) guide
> for more details.
