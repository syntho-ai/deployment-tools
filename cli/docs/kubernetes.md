# Managing Kubernetes Resources with syntho-cli

In this guide, we will walk through how to use `syntho-cli` to effectively manage your resources in a Kubernetes environment.

## Prerequisites

* `syntho-cli` installed ([See Getting Started guide](./getting-started.md))
* A running Kubernetes cluster
* A KUBECONFIG env var to manage resources on Kubernetes cluster
    * Can be both in `yaml content` or a `file path` pointing the kube config
* `kubectl` installed and properly configured
* `helm` installed and properly configured
* An active internet connection on the host where the CLI is going to run
* Other command line utilities: `tar`, `awk`, `curl or wget` and `jq`
* The nodes within the Kubernetes cluster must be of the `amd64` architecture


## Overview

`syntho-cli` interacts with Kubernetes to automate the deployment and management of Syntho applications.

## Running `syntho-cli` for Kubernetes

Below are examples of common tasks you might want to perform with `syntho-cli` in Kubernetes:

> TL;DR: `syntho-cli k8s --help`

### Deploy a Release

To deploy a new release:


Option 1;
```
syntho-cli k8s deployment \
    --license-key <license-key> \
    --registry-user <syntho-image-registry-user> \
    --registry-pwd <syntho-image-registry-password> \
    --kubeconfig $KUBECONFIG \
    --version <syntho-stack-version>
```

Option 2;
- Pre-requirement: Pre pulling images to a [trusted image registry](./utilities.md#pulling-images-into-a-trusted-image-registry)

```
syntho-cli k8s deployment \
    --license-key <license-key> \
    --kubeconfig $KUBECONFIG \
    --version <syntho-stack-version> \
    --trusted-registry-image-pull-secret <k8s-secret-to-be-used-for-pulling-images-from-your-trusted-registry> \
    --use-trusted-registry
```

> Ask Syntho team to fetch your credentials and the version for Syntho resources

> Deployment process takes roughly 10 mins as it is going to be managing various resources.
> When the deployment is finished, a deployment id is generated by the CLI and it is stored under
> the CLI's metadata. Which means, with CLI, this deployment can be managed later on.


#### Updating Release

To update the release:

```
syntho-cli k8s update \
    --deployment-id <deployment-id> \
    --new-version <desired-syntho-stack-version>
```

#### Configuration

During the deployment, there will be a few questions, regarding how you would like to configure
your Syntho setup.

> You don't need to pay extra attention to here unless you really want to, because CLI will guide you
 to provide these configuration values.

##### Volume Setup

There are some resources that need a volume to store their data. You either will need to provide a
storage class for the volume provisioner. Or, if you would like to use an existing volume,
then this volume should be labelled with `pv-label-key` attr and it will need to be provided when
this configuration question is asked.

##### Ingress Class

There will be an ingress record for you to access Syntho UI via a domain (this will be asked, too).
And, CLI will need to receive that info to setup an Ingress Record properly.

##### Other Configuration Values

- Access protocol: http or https
- Domain: your.domain.com - a domain for you to access the Syntho UI
- Ray Head Resources: Ray Head instance will be configured based on the given inputs
- Syntho UI Login Credentials: You are defining your own credentials to login the Syntho UI

> Each configuration questions have a default value if they are not provided. And, CLI will
> smoothly guide you till the end.


### Seeing the Existing Deployments and Their Statuses

To see the existing deployments:

```
syntho-cli k8s deployments
```

You will see an output similar to below

```
- cluster_name: gke_dev-ops-central_us-central1-a_dev-ops-central-gke
  finished_at: '2024-02-01T28:51:21.0829315'
  id: k8s-ac37ceddc8f7f02200ba117a694d38bb
  started_at: '2024-02-01T17:53:37.089944'
  status: completed
  version: 0.1.0-alpha.10

```

### Seeing an Existing Deployment and Its Status

To see an existing deployment:

```
syntho-cli k8s status --deployment-id k8s-ac37ceddc8f7f02200ba117a694d38bb
```

You will see an output similar to below

```
cluster_name: gke_dev-ops-central_us-central1-a_dev-ops-central-gke
finished_at: '2024-02-01T28:51:21.0829315'
id: k8s-ac37ceddc8f7f02200ba117a694d38bb
started_at: '2024-02-01T17:53:37.089944'
status: completed
version: 0.1.0-alpha.10

```

### Destroying an Existing Deployment

To destroy an existing deployment:

```
syntho-cli k8s destroy --deployment-id k8s-ac37ceddc8f7f02200ba117a694d38bb
```

> Deployment metadata alongside existing Syntho Kubernetes resources will be deleted
